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

  def test_development_uses_selected_workflow_ref_without_duplicate_source_input
    refute_includes @workflow, "source_ref:"
    assert_includes @workflow, 'SELECTED_RELEASE_SHA: ${{ github.sha }}'
    assert_includes @workflow, 'echo "RELEASE_REF=$SELECTED_RELEASE_SHA"'
  end

  def test_environments_deploy_independently
    assert_includes @workflow, 'group: vps-bot-${{ inputs.environment }}'
    refute_includes @workflow, "active-environment"
    refute_includes @workflow, "FORCE_ACTIVATE"
  end

  def test_production_requires_an_explicit_valid_tag_from_master
    assert_includes @workflow, "production_tag:"
    assert_includes @workflow, 'WORKFLOW_REF: ${{ github.ref }}'
    assert_includes @workflow, 'if [[ "$WORKFLOW_REF" != refs/heads/master ]]'
    assert_includes @workflow, 'if [[ -z "$PRODUCTION_TAG" ]]'
    assert_includes @workflow, 'git check-ref-format "refs/tags/$PRODUCTION_TAG"'
    assert_includes @workflow, 'echo "RELEASE_REF=refs/tags/$PRODUCTION_TAG"'
  end
end
