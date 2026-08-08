require "minitest/autorun"

class DeployWorkflowContractTest < Minitest::Test
  WORKFLOW = File.expand_path("../.github/workflows/deploy-vps.yml", __dir__)

  def setup
    @workflow = File.read(WORKFLOW)
  end

  def test_development_uses_selected_workflow_ref_without_duplicate_source_input
    refute_includes @workflow, "source_ref:"
    assert_includes @workflow, "SELECTED_RELEASE_SHA: ${{ github.event_name == 'workflow_dispatch' && github.sha"
    assert_includes @workflow, 'echo "RELEASE_REF=$SELECTED_RELEASE_SHA"'
  end

  def test_production_requires_an_explicit_tag_from_master
    assert_includes @workflow, "production_tag:"
    assert_includes @workflow, 'if [[ "${{ github.ref }}" != refs/heads/master ]]'
    assert_includes @workflow, 'if [[ -z "$PRODUCTION_TAG" ]]'
    assert_includes @workflow, 'echo "RELEASE_REF=refs/tags/$PRODUCTION_TAG"'
  end
end
