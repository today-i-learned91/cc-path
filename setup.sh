#!/bin/sh
# setup.sh — Interactive installer for cc-path harness files
# Usage: ./setup.sh [--dry-run]
# One-liner: curl -fsSL https://raw.githubusercontent.com/today-i-learned91/cc-path/main/setup.sh | bash
set -e

# ─── Colors & helpers ─────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    GRN=$(tput setaf 2) YLW=$(tput setaf 3) BLU=$(tput setaf 4)
    BLD=$(tput bold) RST=$(tput sgr0)
else GRN="" YLW="" BLU="" BLD="" RST=""; fi

info()    { printf '%s[info]%s  %s\n' "$BLU" "$RST" "$1"; }
ok()      { printf '%s[ok]%s    %s\n' "$GRN" "$RST" "$1"; }
warn()    { printf '%s[warn]%s  %s\n' "$YLW" "$RST" "$1"; }
die()     { warn "$1" >&2; exit 1; }
ask()     { printf '%s%s%s (%s) [%s]: ' "$BLD" "$1" "$RST" "$2" "$3"; read -r REPLY; REPLY="${REPLY:-$3}"; }

# ─── Flags ────────────────────────────────────────────────────────────────────
DRY=false
for a in "$@"; do case "$a" in
    --dry-run) DRY=true ;;
    -h|--help) printf 'Usage: setup.sh [--dry-run]\n'; exit 0 ;;
    *) die "Unknown flag: $a" ;;
esac; done

# ─── Resolve harness source (local repo or git clone) ─────────────────────────
SDIR="$(cd "$(dirname "$0" 2>/dev/null || echo ".")" && pwd)"
if [ -d "$SDIR/harness" ]; then
    SRC="$SDIR/harness"
else
    info "Downloading cc-path harness files..."
    TD=$(mktemp -d); trap 'rm -rf "$TD"' EXIT
    git clone --depth 1 --quiet https://github.com/today-i-learned91/cc-path.git "$TD"
    SRC="$TD/harness"
fi

# ─── Banner & prompts ─────────────────────────────────────────────────────────
printf '\n%s' "${BLD}${BLU}"
cat <<'BANNER'
    ┌─────────────────────────────────────────┐
    │  cc-path  ·  harness installer          │
    │  Philosophy as Architecture             │
    └─────────────────────────────────────────┘
BANNER
printf '%s\n' "$RST"
[ "$DRY" = true ] && warn "DRY RUN — no files will be written"

# 1) Project directory
ask "Project directory" "path" "$(pwd)"; TARGET="$REPLY"
TARGET=$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")
[ -d "$TARGET" ] || die "Directory does not exist: $TARGET"

# 2) Project type (controls which formatter stays in settings.json)
ask "Project type" "python/typescript/general" "general"; PTYPE="$REPLY"
case "$PTYPE" in python|typescript|general) ;; *) die "Invalid type: $PTYPE" ;; esac

# 3) Safety level
ask "Safety level" "standard/strict" "standard"; SAFETY="$REPLY"
case "$SAFETY" in standard|strict) ;; *) die "Invalid level: $SAFETY" ;; esac

# 4) Example skills
ask "Include example skills?" "y/n" "y"
case "$REPLY" in y|Y|yes) SKILLS=true ;; *) SKILLS=false ;; esac

# ─── Build file manifest ──────────────────────────────────────────────────────
# All paths are relative to harness/ and identical for source and destination.
FILES="CLAUDE.md
.claude/CLAUDE.md
.claude/settings.json
.claude/rules/thinking-framework.md
.claude/rules/document-management.md
.claude/rules/sub-project-convention.md
.claude/rules/graceful-degradation.md
.claude/hooks/deploy-guard.sh
.claude/hooks/circuit-breaker.sh
.claude/hooks/circuit-breaker-gate.sh
.claude/hooks/circuit-breaker-reset.sh"

if [ "$SAFETY" = "strict" ]; then
    FILES="$FILES
.claude/hooks/cognitive-protection.sh
.claude/hooks/input-sanitizer.sh
.claude/hooks/decision-audit.sh
.claude/rules/cognitive-protection.md"
fi

if [ "$SKILLS" = true ]; then
    FILES="$FILES
.claude/skills/build.md
.claude/skills/code-review.md
.claude/skills/research.md"
fi

# ─── Copy engine ──────────────────────────────────────────────────────────────
printf '%s\n' "$FILES" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    sp="$SRC/$f"; dp="$TARGET/$f"
    [ -f "$sp" ] || { warn "Missing source: $f"; continue; }

    # Existing file guard — ask to overwrite (dry-run always skips)
    if [ -f "$dp" ]; then
        if [ "$DRY" = true ]; then
            warn "Exists (skip): $f"; continue
        fi
        printf '  %sExists:%s %s — overwrite? (y/n) [n]: ' "$YLW" "$RST" "$f"
        read -r ow; case "$ow" in y|Y|yes) ;; *) continue ;; esac
    fi

    if [ "$DRY" = true ]; then ok "Would copy: $f"
    else mkdir -p "$(dirname "$dp")"; cp "$sp" "$dp"; ok "Copied: $f"; fi
done

# ─── Post-copy adjustments (permissions, formatter, safety hooks) ─────────────
if [ "$DRY" = false ]; then
    # Executable hooks
    [ -d "$TARGET/.claude/hooks" ] && chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

    # Adjust formatter for project type
    SF="$TARGET/.claude/settings.json"
    if [ -f "$SF" ]; then
        case "$PTYPE" in
            python)     sed -i.bak 's|js\|ts\|tsx\|jsx) npx --no-install prettier --write|js\|ts\|tsx\|jsx) true \&\& : #|' "$SF" 2>/dev/null || true ;;
            typescript) sed -i.bak 's|py) ruff format|py) true \&\& : #|' "$SF" 2>/dev/null || true ;;
        esac

        # Strip strict-only hook references from settings.json when standard
        if [ "$SAFETY" = "standard" ]; then
            sed -i.bak \
                -e '/cognitive-protection\.sh/d' -e '/Sensitive operation check/d' \
                -e '/input-sanitizer\.sh/d'      -e '/Input validation/d' \
                "$SF" 2>/dev/null || true
        fi
        rm -f "$SF.bak"
    fi
    ok "Set hook permissions and adjusted settings"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$(printf '%s\n' "$FILES" | grep -c '.')
printf '\n%s── Summary ──────────────────────────────────────%s\n' "$BLD" "$RST"
info "Target:       $TARGET"
info "Project type: $PTYPE"
info "Safety level: $SAFETY  $([ "$SAFETY" = strict ] && echo '(deploy-guard + circuit-breaker + cognitive-protection + input-sanitizer + decision-audit)' || echo '(deploy-guard + circuit-breaker)')"
info "Skills:       $([ "$SKILLS" = true ] && echo 'included (build, code-review, research)' || echo 'skipped')"
info "Files:        $TOTAL total"
printf '\n'

if [ "$DRY" = true ]; then
    info "Re-run without --dry-run to apply changes."
else
    ok "Done! Your cc-path harness is ready."
    printf '  1. Review CLAUDE.md and adjust for your project\n'
    printf '  2. Check .claude/settings.json hook configuration\n'
    printf '  3. Run: claude  to start coding with your harness\n'
fi
printf '\n'
