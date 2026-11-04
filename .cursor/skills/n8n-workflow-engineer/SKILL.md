---
name: n8n-workflow-engineer
description: Build, edit, validate, test, and debug n8n workflows through the official n8n MCP server, with version-history rollback, safe credential handling, and pin-data-first testing. Use this skill whenever the user asks a Cursor agent to create, change, repair, inspect, validate, or test an n8n workflow; investigate failed n8n executions; configure workflow credentials; or recover an n8n workflow version—even if they only say “automation,” name a workflow, or paste an n8n error without explicitly requesting this skill.
compatibility: Requires the official n8n instance-level MCP server and the official n8n skills from n8n-io/skills.
---

# n8n Workflow Engineer

Operate n8n as an engineer, not as a JSON generator. Make the requested change in the user's current workflow draft, prove it with controlled data, and leave a clear rollback path.

## Load maintained guidance first

Read `using-n8n-skills-official`, then read every official capability skill it routes to for the current task. At minimum, workflow creation or editing normally needs:

- `n8n-workflow-lifecycle-official`
- `n8n-node-configuration-official`
- `n8n-expressions-official` when expressions are involved
- `n8n-error-handling-official` for production-bound or webhook workflows
- `n8n-credentials-and-security-official` for any authentication
- `n8n-debugging-official` for failures or unexpected output

Treat the live MCP tool schemas and node definitions as authoritative when they differ from a skill or memory.

If the official n8n MCP tools are unavailable, stop before designing the workflow and help the user connect Cursor through **Settings → Instance-level MCP** in n8n. Never substitute browser clicking, direct database edits, or invented workflow JSON.

## Safety policy

- Edit the current workflow draft directly; a duplicate test workflow is not required.
- Before changing an existing workflow, fetch its details and newest history entry. Record that version ID as the rollback point.
- Draft edits must not silently change production activation. Do not publish, unpublish, archive, or run a production execution unless the user explicitly requests that action.
- Never place tokens, passwords, API keys, or OAuth secrets in workflow fields, code, pin data, chat output, or files. Use n8n credentials.
- Treat a secret pasted into chat as exposed: do not reuse it and tell the user to rotate it.
- Use targeted, atomic `update_workflow` operations for existing workflows. Include a useful version name and description.
- If work must be abandoned after edits and the draft is worse than the captured baseline, restore the rollback version before handing back control.

## Workflow

### 1. Understand and locate

Clarify only requirements that materially change behavior, data contracts, side effects, or destination project/folder.

For existing work:

1. Find the exact workflow with `search_workflows`.
2. If it cannot be found, ask the user to enable **Available in MCP** on that workflow.
3. Fetch `get_workflow_details`.
4. Fetch `get_workflow_history` and record the latest version ID.
5. For a reported failure, inspect the failed execution with `get_workflow_execution(includeData: true)` before editing.

For new work, search for existing workflows and reusable sub-workflows before creating another implementation.

### 2. Plan from live definitions

Describe the input, transformations, output, failure behavior, and side effects in plain language.

Before writing or changing nodes:

1. Read `get_workflow_sdk_reference` when creating SDK code.
2. Read `get_workflow_best_practices` for each relevant technique.
3. Use `search_nodes` to discover suitable nodes.
4. Call `get_node_types` with the exact node IDs and discriminators.
5. Resolve resource IDs with `explore_node_resources` instead of inventing dropdown values.

Prefer native nodes and expressions over Code nodes. Add error handling appropriate to each fallible operation.

### 3. Handle credentials safely

Call `list_credentials` for the exact credential type:

- One suitable match: bind it by ID.
- Multiple suitable matches: ask the user which account/environment to use.
- No match: tell the user the exact credential type to create in n8n, then pause before tests that need it.

Never request the secret value in chat. Before a live test, have the user verify the selected credential on every credentialed node.

### 4. Validate, apply, and verify

Validate each changed node configuration with `validate_node_config` before writing when possible.

For a new workflow:

1. Validate the complete SDK source with `validate_workflow`.
2. Create it with a concise description and version-history metadata.

For an existing workflow:

1. Apply the smallest atomic operation batch with `update_workflow`.
2. Include every official skill used in `skillsUsed`.

After every create or update, fetch `get_workflow_details` and verify:

- Every intended node exists with the expected parameters.
- The connections graph matches the plan.
- Credentials are references, not plaintext.
- Workflow settings and groups were preserved.
- No operation or node group was skipped or removed unexpectedly.

Do not call the change complete merely because schema validation passed.

### 5. Test with pin data first

Read the official lifecycle skill's `references/TESTING.md` before testing.

1. Call `prepare_workflow_pin_data`.
2. Generate realistic nominal input plus relevant empty, malformed, and boundary cases.
3. Pin every trigger, credentialed node, and HTTP Request node returned by the tool.
4. Also pin any node whose real execution could cause side effects, including Data Table writes, file or command operations, side-effecting Code nodes, and Execute Workflow calls.
5. If a side effect cannot be isolated while preserving a meaningful test, explain exactly what would run and ask before proceeding.
6. Run `test_workflow`.
7. Inspect outputs and errors with `get_workflow_execution(includeData: true)`.
8. Compare actual outputs with the requested contract. Fix and rerun using the same pin data until it passes.

After each test, state which nodes were pinned and which nodes executed for real. A successful status alone is insufficient; verify the important output values and branches.

A live or production execution is a separate step. Run one only after pin-data tests pass and the user explicitly confirms the listed side effects, destination accounts, and expected cost.

### 6. Debug systematically

Use evidence in this order:

1. Failed execution and exact failing node.
2. Current workflow details and connection graph.
3. Fresh node definitions and isolated node validation.
4. Controlled reproduction with the smallest representative pin data.
5. n8n source or upstream API documentation if observed behavior contradicts the definitions.

Fix the root cause rather than replacing a failing native node with a Code node. Retest the original failure case and at least one normal case.

### 7. Roll back when needed

Use the captured version ID with `restore_workflow_version` when the user requests rollback or when an abandoned edit left the draft worse. Fetch the restored workflow afterward and verify its nodes and connections.

Restoring creates a new history entry; it does not erase the failed attempt.

## Completion report

Keep the handoff concise:

- **Workflow:** name and direct n8n link
- **Changed:** short description of the final behavior
- **Verified:** validation result, pin-data cases, important output, and pinned-versus-real nodes
- **Rollback:** captured version ID, or state that this was a new workflow
- **Pending:** credential selection, live execution, or other user action

Do not report “done” if validation, graph verification, or representative pin-data tests remain incomplete.
