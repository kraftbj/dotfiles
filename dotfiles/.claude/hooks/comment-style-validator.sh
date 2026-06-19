#!/bin/bash
# Claude Code Hook: Comment Style Validator (PreToolUse)
#
# Warn-only nudge toward the CLAUDE.md rule: "For multi-line comment blocks, use
# a single /* ... */ block instead of stacking multiple single-line // comments."
#
# Fires on Edit/Write/MultiEdit for C-style (// line-comment) files. If the newly
# added content contains 3+ consecutive prose-style // comment lines, it surfaces
# a warning to the user and injects a reminder into the model's context so the
# next pass can collapse them into a /* ... */ block. It never blocks the edit —
# false positives cost a reminder, not a rejected tool call.
#
# Heuristics that keep false positives low:
# - Only 3+ consecutive // lines trip it (2-line notes are left alone).
# - Lines that look like commented-out code (end in ; { } , contain =>, or start
#   with a closing bracket) are not counted as prose, so disabled code blocks
#   don't fire it.
# - At least 2 of the consecutive lines must read as prose (letters + a space).

# Read JSON input from stdin
JSON_DATA=$(cat)

TOOL_NAME=$(echo "$JSON_DATA" | jq -r '.tool_name // ""')

# Only the file-editing tools.
case "$TOOL_NAME" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(echo "$JSON_DATA" | jq -r '.tool_input.file_path // ""')

# Only languages where // is a single-line comment.
case "$FILE_PATH" in
    *.php|*.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.c|*.h|*.cpp|*.cc|*.cxx|*.hpp|*.hh|*.java|*.go|*.rs|*.swift|*.kt|*.kts|*.scala|*.cs|*.m|*.mm|*.scss|*.less|*.dart|*.proto) ;;
    *) exit 0 ;;
esac

# Pull the newly added content for each tool shape.
case "$TOOL_NAME" in
    Write)     NEW_CONTENT=$(echo "$JSON_DATA" | jq -r '.tool_input.content // ""') ;;
    Edit)      NEW_CONTENT=$(echo "$JSON_DATA" | jq -r '.tool_input.new_string // ""') ;;
    MultiEdit) NEW_CONTENT=$(echo "$JSON_DATA" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")') ;;
esac

[ -z "$NEW_CONTENT" ] && exit 0

# Detect a run of 3+ consecutive prose // comment lines. Pass the content through
# the environment to avoid any shell interpolation of its contents.
VIOLATION=$(CC_CONTENT="$NEW_CONTENT" perl -e '
    my $text = $ENV{CC_CONTENT} // "";
    my @lines = split /\n/, $text, -1;
    my ($run, $prose, $flag) = (0, 0, 0);
    for my $l (@lines) {
        if ($l =~ m{^\s*//\s?(.*)$}) {
            my $b = $1;
            $run++;
            my $codeish = ($b =~ /[;{},]\s*$/) || ($b =~ /=>/) || ($b =~ /^\s*[\}\)\]]/);
            my $proseish = (!$codeish) && ($b =~ /[A-Za-z]/) && ($b =~ / /);
            $prose++ if $proseish;
        } else {
            $flag = 1 if ($run >= 3 && $prose >= 2);
            $run = 0; $prose = 0;
        }
    }
    $flag = 1 if ($run >= 3 && $prose >= 2);
    print $flag;
')

if [ "$VIOLATION" = "1" ]; then
    MSG="Stacked // comments in $(basename "$FILE_PATH"): 3+ consecutive single-line // comments form a multi-line block. Per CLAUDE.md, collapse them into a single /* ... */ block. Reserve // for genuinely single-line comments."
    jq -n --arg m "$MSG" '{
        systemMessage: ("⚠️  " + $m),
        hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: $m }
    }'
    exit 0
fi

exit 0
