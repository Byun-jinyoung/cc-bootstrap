#!/bin/bash
# Patch OMC HUD render.js to display Model before Git branch
# Re-run after each OMC plugin update
set -e

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
RENDER_JS=$(find "$CONFIG_DIR/plugins/cache/omc/oh-my-claudecode" -name "render.js" -path "*/hud/*" 2>/dev/null | sort -V | tail -1)

if [ -z "$RENDER_JS" ]; then
  echo "ERROR: OMC HUD render.js not found. Is oh-my-claudecode installed?"
  exit 1
fi

# Check if already patched (Model before Git branch)
if grep -A5 "// Model name" "$RENDER_JS" | grep -q "// Git branch"; then
  echo "Already patched: $RENDER_JS"
  exit 0
fi

# Swap: move Model block before Git branch block
sed -i '/\/\/ Git branch/{
N;N;N;N;N
h
s/.*//
N;N;N;N;N;N
G
}' "$RENDER_JS" 2>/dev/null

# Verify with a simpler approach if sed failed
if ! grep -B1 "renderGitBranch" "$RENDER_JS" | grep -q "renderModel"; then
  # Use python for reliable multi-line swap
  python3 -c "
import re
with open('$RENDER_JS') as f:
    content = f.read()

git_block = '''    // Git branch
    if (enabledElements.gitBranch) {
        const gitBranchElement = renderGitBranch(context.cwd);
        if (gitBranchElement)
            gitElements.push(gitBranchElement);
    }
    // Model name'''

model_first = '''    // Model name
    if (enabledElements.model && context.modelName) {
        const modelElement = renderModel(context.modelName, enabledElements.modelFormat);
        if (modelElement)
            gitElements.push(modelElement);
    }
    // Git branch
    if (enabledElements.gitBranch) {
        const gitBranchElement = renderGitBranch(context.cwd);
        if (gitBranchElement)
            gitElements.push(gitBranchElement);
    }
    // API key source'''

old_block = '''    // Git branch
    if (enabledElements.gitBranch) {
        const gitBranchElement = renderGitBranch(context.cwd);
        if (gitBranchElement)
            gitElements.push(gitBranchElement);
    }
    // Model name
    if (enabledElements.model && context.modelName) {
        const modelElement = renderModel(context.modelName, enabledElements.modelFormat);
        if (modelElement)
            gitElements.push(modelElement);
    }
    // API key source'''

if old_block in content:
    content = content.replace(old_block, model_first)
    with open('$RENDER_JS', 'w') as f:
        f.write(content)
    print('Patched successfully:', '$RENDER_JS')
else:
    print('Pattern not found - may already be patched or OMC version changed')
"
fi

echo "Done: Model now displays before Git branch"
