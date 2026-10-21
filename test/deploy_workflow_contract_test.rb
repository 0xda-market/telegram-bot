require "minitest/autorun"

class DeployWorkflowContractTest < Minitest::Test
  WORKFLOW = File.expand_path("../.github/workflows/deploy-vps.yml", __dir__)

  def setup
    @workflow = File.read(WORKFLOW)
  end

  def test_deployment_is_manual_only
    assert_includes @workflow, "workflow_dispatch:"
    refute_includes @workflow, "pull_request:"
    refute_includes @workflow, "github.event.pull_request"
  end

  def test_development_uses_master_and_exact_ci
    assert_includes @workflow, "refs/heads/master"
    assert_includes @workflow, "head_sha=$GITHUB_SHA"
    assert_includes @workflow, "aiaiaiai-org/infra"
  end

  def test_environment_is_development_only
    assert_includes @workflow, "group: market-bot-development-deploy"
    assert_includes @workflow, "name: development"
    assert_includes @workflow, "market-bot-test"
    refute_includes @workflow, "production_tag:"
  end
end
