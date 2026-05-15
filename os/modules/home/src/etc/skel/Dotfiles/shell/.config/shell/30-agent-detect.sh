# 30-agent-detect.sh — detect AI agent shells (POSIX).
#
# Sets SILVERFOX_AGENT_SHELL=1 if any known agent marker env var is set.
# Used by later modules (aliases) to skip injection of ANSI/icons that
# break agents parsing command output.
#
# Cross-tool conventions checked (May 2026):
#   AGENT, AI_AGENT      proposal (agentsmd #136) + Vercel detect-agent
#   CLAUDECODE           Claude Code
#   CURSOR_AGENT         Cursor agent CLI
#   CURSOR_TRACE_ID      Cursor in-editor terminal
#   GEMINI_CLI           Google Gemini CLI
#   CODEX_SANDBOX        OpenAI Codex CLI ("seatbelt")
#   AUGMENT_AGENT        Augment
#   CLINE_ACTIVE         Cline
#   OPENCODE_CLIENT      sst/opencode
#   TRAE_AI_SHELL_ID     TRAE AI
#   ANTIGRAVITY_AGENT    Antigravity
#   REPL_ID              Replit
#   COPILOT_MODEL        GitHub Copilot CLI
#   SILVERFOX_NO_ALIASES   manual opt-out

SILVERFOX_AGENT_SHELL=
for _v in AGENT AI_AGENT \
          CLAUDECODE \
          CURSOR_AGENT CURSOR_TRACE_ID \
          GEMINI_CLI \
          CODEX_SANDBOX \
          AUGMENT_AGENT \
          CLINE_ACTIVE \
          OPENCODE_CLIENT \
          TRAE_AI_SHELL_ID \
          ANTIGRAVITY_AGENT \
          REPL_ID \
          COPILOT_MODEL \
          SILVERFOX_NO_ALIASES; do
    eval "_val=\${$_v:-}"
    if [ -n "$_val" ]; then
        SILVERFOX_AGENT_SHELL=1
        break
    fi
done
unset _v _val
export SILVERFOX_AGENT_SHELL
