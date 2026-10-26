# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT

require_relative "test_helper"
require "yaml"
require "open3"
require "tmpdir"
require "json"

class MarketStackDeployWorkflowTest < Minitest::Test
  WORKFLOW = File.expand_path("../.github/workflows/deploy-stack.yml", __dir__)
  BOT_WORKFLOW = File.expand_path("../.github/workflows/deploy-vps.yml", __dir__)
  SCRIPT = File.expand_path("../scripts/deploy-development-stack.sh", __dir__)

  def test_manual_only_deploy_with_one_serial_concurrency_group
    contents = File.read(WORKFLOW)
    workflow = YAML.safe_load(contents, aliases: false)
    assert_includes contents, "workflow_dispatch:"
    refute_match(/^\s+(push|pull_request|schedule):/, contents)
    assert_equal false, workflow.dig("concurrency", "cancel-in-progress")
    assert_equal "development", workflow.dig("jobs", "orchestrate", "environment", "name")
    assert_includes contents, "secrets.MARKET_ORCHESTRATION_TOKEN"
    refute_match(/SSH_(HOST|USER|PRIVATE_KEY)/, contents)
  end

  def test_ordered_downstream_workflows_and_exact_sha_guard
    contents = File.read(SCRIPT)
    assert_operator contents.index('dispatch_and_await "$core_repo"'), :<,
      contents.index('dispatch_and_await "$web_repo"')
    assert_operator contents.index('dispatch_and_await "$web_repo"'), :<,
      contents.index('dispatch_and_await "$bot_repo"')
    assert_includes contents, 'pinned_web_sha'
    assert_includes contents, 'head_sha=$sha'
    assert_includes contents, '.event == "push"'
    assert_includes contents, '.conclusion == "success"'
    assert_includes contents, 'request_id'
    assert_includes contents, 'workflow_dispatch'
    refute_includes contents, 'scp '
    refute_match(/\bssh -/, contents)
  end

  def test_bot_deploy_confirms_infra_activation
    contents = File.read(BOT_WORKFLOW)
    assert_includes contents, "run-name: Deploy Market Bot"
    assert_includes contents, "request_id:"
    assert_includes contents, "Verify matching infra activation and health"
    assert_includes contents, 'request_id: $request_id'
    assert_includes contents, 'title="Deploy $WORKLOAD / $GITHUB_RUN_ID"'
  end

  def test_stack_script_and_inline_workflow_steps_are_valid_bash
    _out, err, status = Open3.capture3("bash", "-n", SCRIPT)
    assert status.success?, err
    YAML.safe_load(File.read(WORKFLOW), aliases: false).fetch("jobs").each_value do |job|
      job.fetch("steps").each do |step|
        next unless step["run"]
        _out, error, result = Open3.capture3("bash", "-n", stdin_data: step["run"])
        assert result.success?, error
      end
    end
  end
  FAKE_GH = <<~'FAKE_RUBY'
    #!/usr/bin/env ruby
    require "json"
    state_path = ENV.fetch("FAKE_GH_STATE")
    state = JSON.parse(File.read(state_path))
    abort "gh mock only accepts api" unless ARGV.first == "api"
    method_index = ARGV.index("--method")
    method = method_index ? ARGV.fetch(method_index + 1) : "GET"
    endpoint = ARGV.find { |value| value.start_with?("repos/") } || abort("missing endpoint")

    if method == "POST"
      payload = JSON.parse(STDIN.read)
      state.fetch("dispatches") << {
        "repo" => endpoint.sub("repos/", "").split("/actions/workflows/").first,
        "workflow" => endpoint.split("/workflows/").last.split("/").first,
        "request_id" => payload.fetch("inputs").fetch("request_id")
      }
      File.write(state_path, JSON.generate(state))
      exit 0
    end

    if endpoint.end_with?("/commits/master")
      repo = endpoint.delete_prefix("repos/").delete_suffix("/commits/master")
      puts state.fetch("master").fetch(repo)
      exit 0
    end

    if endpoint.include?("/actions/runs?")
      repo = endpoint.delete_prefix("repos/").split("/actions/runs?").first
      sha = endpoint[/head_sha=([a-f0-9]{40})/, 1] || abort("missing sha")
      success = state["ci_failure"] == repo ? "failure" : "success"
      runs = [{
        "head_sha" => sha,
        "head_branch" => "master",
        "event" => "push",
        "path" => ".github/workflows/ci.yml",
        "status" => "completed",
        "conclusion" => success
      }]

      labels = {
        "0xda-market/core" => "Core",
        "0xda-market/webapp-core" => "WebApp",
        "0xda-market/telegram-bot" => "Bot"
      }
      state.fetch("dispatches").each_with_index do |dispatch, index|
        next unless dispatch.fetch("repo") == repo
        runs << {
          "id" => index + 1,
          "display_title" => "Deploy Market #{labels.fetch(repo)} #{dispatch.fetch("request_id")}",
          "head_sha" => state.fetch("master").fetch(repo),
          "head_branch" => "master",
          "event" => "workflow_dispatch",
          "path" => ".github/workflows/#{dispatch.fetch("workflow")}",
          "status" => "completed",
          "conclusion" => state["deploy_failure"] == repo ? "failure" : "success"
        }
      end
      puts JSON.generate({ "workflow_runs" => runs })
      exit 0
    end
    abort "unexpected GH endpoint: #{endpoint}"
  FAKE_RUBY

  def simulate_stack(ci_failure: nil, deploy_failure: nil, pinned_mismatch: false)
    Dir.mktmpdir("market-stack-contract") do |directory|
      bin = File.join(directory, "bin")
      Dir.mkdir(bin)
      gh_path = File.join(bin, "gh")
      File.write(gh_path, FAKE_GH)
      File.chmod(0o755, gh_path)
      pin = File.read(File.expand_path("../webapp/app.js", __dir__))
        .match(/^const WEBAPP_CORE_REVISION = "([a-f0-9]{40})";$/).captures.first
      master = {
        "0xda-market/core" => "a" * 40,
        "0xda-market/webapp-core" => pinned_mismatch ? "c" * 40 : pin,
        "0xda-market/telegram-bot" => "b" * 40
      }
      state_path = File.join(directory, "state.json")
      File.write(state_path, JSON.generate({
        "master" => master,
        "dispatches" => [],
        "ci_failure" => ci_failure,
        "deploy_failure" => deploy_failure
      }))
      env = {
        "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
        "FAKE_GH_STATE" => state_path,
        "GITHUB_REF" => "refs/heads/master",
        "GITHUB_SHA" => master.fetch("0xda-market/telegram-bot"),
        "GITHUB_RUN_ID" => "12345",
        "GITHUB_RUN_ATTEMPT" => "1",
        "GITHUB_STEP_SUMMARY" => File.join(directory, "summary.md"),
        "GH_TOKEN" => "fake-token"
      }
      stdout, stderr, status = Open3.capture3(env, "bash", SCRIPT,
        chdir: File.expand_path("..", __dir__))
      result = JSON.parse(File.read(state_path))
      yield status, stdout, stderr, result
    end
  end

  def test_fake_gh_stack_completes_in_order
    simulate_stack do |status, _stdout, stderr, result|
      assert status.success?, stderr
      assert_equal %w[0xda-market/core 0xda-market/webapp-core 0xda-market/telegram-bot],
        result.fetch("dispatches").map { |item| item.fetch("repo") }
      assert result.fetch("dispatches").all? { |item| item["request_id"] == "stack-12345-1" }
    end
  end

  def test_fail_closed_if_webapp_ci_is_missing
    simulate_stack(ci_failure: "0xda-market/webapp-core") do |status, _stdout, stderr, result|
      refute status.success?
      assert_includes stderr, "Missing green exact-head push Full CI"
      assert_empty result.fetch("dispatches")
    end
  end

  def test_fail_closed_when_mini_app_pin_is_not_webapp_master
    simulate_stack(pinned_mismatch: true) do |status, _stdout, stderr, result|
      refute status.success?
      assert_includes stderr, "pins"
      assert_empty result.fetch("dispatches")
    end
  end

  def test_stop_before_webapp_after_core_activation_failure
    simulate_stack(deploy_failure: "0xda-market/core") do |status, _stdout, stderr, result|
      refute status.success?
      assert_includes stderr, "deployment failed"
      assert_equal ["0xda-market/core"], result.fetch("dispatches").map { |item| item.fetch("repo") }
    end
  end

end
