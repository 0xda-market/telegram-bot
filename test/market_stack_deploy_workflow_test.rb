# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT

require_relative "test_helper"
require "yaml"
require "open3"

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
end
