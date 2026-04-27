# Pipeline Integration Guide

This document explains how to integrate the E2E tests into the AWS CodePipeline to replace the manual approval step for Beta deployments.

## Overview

The E2E test suite will run automatically after Beta deployment and before any Prod deployment. This replaces the manual approval for Beta while keeping manual approval for Prod.

## Current Pipeline Structure

```
Source (GitHub)
  → Build/Synth
    → Deploy Beta
      → Manual Approval ← REPLACE THIS
        → Deploy Prod
          → Manual Approval ← KEEP THIS
```

## Target Pipeline Structure

```
Source (GitHub)
  → Build/Synth
    → Deploy Beta
      → Run E2E Tests ← NEW: Replaces Beta manual approval
        → Deploy Prod
          → Manual Approval ← Keep for production safety
```

## Implementation Steps

### 1. Modify `lib/stacks/pipeline.ts`

Replace lines 79-86 with conditional logic:

```typescript
// Add test stage for Beta, keep manual approval for Prod
if (stage === STAGE.BETA) {
    // Beta: Run E2E tests instead of manual approval
    deploymentStage.addPost(new CodeBuildStep(`E2E-Tests-${stageId}`, {
        projectName: `AidouiE2ETests-${stage}`,
        input: CodePipelineSource.connection(
            'OUIEnterprises/AidouiTests',
            'main',
            { connectionArn }
        ),
        commands: [], // Uses buildspec.yml from the repository
        buildEnvironment: {
            buildImage: codebuild.LinuxBuildImage.STANDARD_7_0,
        },
    }));
} else {
    // Prod: Keep manual approval for safety
    deploymentStage.addPost(new ManualApprovalStep(`ManualApproval-${stageId}`, {
        comment: `Please approve the deployment to ${stageId}`,
    }));
}
```

### 2. Required Imports

Add to the top of `pipeline.ts`:

```typescript
import { CodeBuildStep } from 'aws-cdk-lib/pipelines';
import * as codebuild from 'aws-cdk-lib/aws-codebuild';
```

### 3. Test Execution Flow

When tests run:

1. **CodeBuild pulls** AidouiTests repository
2. **Maven installs** dependencies
3. **JUnit executes** test suite against Beta API
4. **Test results** are published to CodeBuild reports
5. **Pipeline continues** if tests pass, stops if tests fail

### 4. Test Failure Handling

If any test fails:
- Pipeline STOPS (doesn't deploy to Prod)
- Test reports available in CodeBuild console
- Developers fix issues and commit
- Pipeline re-runs automatically

## Benefits

✅ **Automated Validation** - No human intervention needed for Beta
✅ **Faster Deployments** - No waiting for manual approval
✅ **Regression Prevention** - Broken builds caught before Prod
✅ **Test Reports** - JUnit XML reports in CodeBuild
✅ **Production Safety** - Manual approval still required for Prod

## Test Coverage

The E2E tests validate:
- Authentication (login, tokens)
- Records API (view, share, access control)
- Authorization (token types, permissions)
- Complete user workflows

See [README.md](README.md) for full test documentation.

## Rollback Plan

If tests are problematic:
1. Revert changes to `pipeline.ts`
2. Restore `ManualApprovalStep` for Beta
3. Fix test issues in AidouiTests repository
4. Re-enable automated tests

## Monitoring

Monitor test executions:
- AWS CodePipeline console - Pipeline execution history
- AWS CodeBuild console - Test run logs
- CloudWatch Logs - Detailed test output

## Next Steps

1. Deploy pipeline changes to enable E2E tests
2. Verify first test run passes
3. Monitor for false positives/negatives
4. Expand test coverage as needed
5. Consider adding performance/load tests

## Related Files

- `buildspec.yml` - Test execution configuration
- `pom.xml` - Maven dependencies
- `src/test/resources/test-beta.properties` - Test configuration
- `src/test/java/com/aidoui/e2e/RecordsEndpointsTest.java` - Main test class
