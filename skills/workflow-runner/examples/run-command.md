# Workflow Runner Example

```bash
bash skills/workflow-runner/scripts/run_microservice_requirement.sh \
  --main-dir /path/main-service \
  --deps /path/order-service,/path/charge-service \
  --requirement-key occupancy_interconnect \
  --feature-branch feature_occupancyInterconnectAlign \
  --owner agent-main \
  --auto-phase true \
  --auto-commit false
```
