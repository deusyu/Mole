# Mole CLI JSON Contract

Mole JSON output is intended for scripts, AI agents, and future GUI consumers.
Reporting commands are read-only. They describe observed disk usage and point to
existing Mole commands for any cleanup action.

## Stability

- `schema_version` identifies the output shape.
- Adding optional fields is allowed in minor releases.
- Renaming or removing fields requires release notes.
- `size_bytes` is always a JSON number of bytes, not human-readable text. When
  size cannot be measured, emit `null`.
- Consumers should ignore unknown fields.

## Report Output

`mo report --json` emits a top-level object:

```json
{
  "schema_version": 1,
  "command": "report",
  "generated_at": "2026-05-28T00:00:00Z",
  "summary": {
    "total_observed_bytes": 0,
    "low_risk_bytes": 0,
    "medium_risk_bytes": 0,
    "high_risk_bytes": 0
  },
  "developer_projects": [],
  "dev_caches": [],
  "installers": [],
  "history": {},
  "recommended_commands": [],
  "protected_or_skipped": []
}
```

## Shared Item Fields

Machine-readable cleanup and reporting item arrays should use this shape where
possible:

```json
{
  "path": "/absolute/path",
  "name": "node_modules",
  "category": "project_artifact",
  "ecosystem": "node",
  "size_bytes": 123456,
  "risk_level": "low",
  "risk_reason": "Regenerable dependency directory",
  "recoverable": false,
  "protected": false,
  "whitelisted": false,
  "selected_by_default": true,
  "recommended_action": "purge"
}
```

Fields:

- `path`: absolute filesystem path when available.
- `name`: display name or basename.
- `category`: stable category string.
- `ecosystem`: ecosystem such as `node`, `python`, or `rust`; use `null` when
  unknown.
- `size_bytes`: numeric bytes or `null`.
- `risk_level`: one of `low`, `medium`, or `high`.
- `risk_reason`: short human-readable reason for the risk classification.
- `recoverable`: whether the recommended existing cleanup path is recoverable.
- `protected`: true when Mole policy treats the item as protected.
- `whitelisted`: true when the item matches the user whitelist.
- `selected_by_default`: true only when the existing command would select the
  item by default using conservative semantics.
- `recommended_action`: short action key such as `purge`, `installer`,
  `analyze`, `history`, `manual_review`, or `none`.

## Risk Levels

- `low`: cache, build output, dependency directory, or regenerable artifact.
- `medium`: installer, old download, archive, app data, or item where user
  context matters.
- `high`: system path, preference/config/session data, credential-adjacent data,
  or anything requiring stronger review.

## MVP Categories

- `project_artifact`
- `dev_cache`
- `installer`
- `app`
- `ai_tool_cache`
- `ai_tool_workspace`
- `protected_data`
- `history`
- `unknown`

## Safety Contract

JSON and Markdown reporting modes must not delete files, request authorization,
prompt for interactive selection, or mutate configuration. Cleanup remains
available through existing Mole commands such as `mo purge --dry-run`,
`mo installer --dry-run`, and `mo analyze`.
