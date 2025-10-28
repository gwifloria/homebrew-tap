class ClaudeMonitor < Formula
  desc "Real-time ClaudeCode status in your macOS menu bar"
  homepage "https://github.com/gwifloria/claude-monitor"
  url "https://github.com/gwifloria/claude-monitor/archive/refs/tags/v0.2.4.tar.gz"
  sha256 "71e9802b123e7d90727e76c63beff2af627b5cfc6bdb0e3473d8191e2fb0667d"
  license "MIT"
  version "0.2.4"

  depends_on "jq"

  def install
    # Install core library files
    (prefix/"lib").install "lib/status_manager.sh"

    # Install hook scripts
    (prefix/"hooks").install "hooks/update_status.sh"

    # Install SwiftBar plugin
    (prefix/"plugins").install "plugins/claude_monitor.1s.sh"

    # Install management scripts
    (prefix/"scripts").install "scripts/swiftbar_manager.sh"
    (prefix/"scripts").install "scripts/generate_settings.sh"

    # Install documentation
    doc.install "README.md"
    doc.install "README.zh-CN.md"
    doc.install "CLAUDE.md" if File.exist?("CLAUDE.md")
    doc.install "docs" if Dir.exist?("docs")

    # Create executable wrapper
    (bin/"claude-monitor").write <<~EOS
      #!/bin/bash
      exec "#{prefix}/scripts/swiftbar_manager.sh" "$@"
    EOS

    # Create setup script
    (bin/"claude-monitor-setup").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      CLAUDE_MONITOR_PREFIX="#{prefix}"
      CLAUDE_CONFIG_DIR="$HOME/.claude"
      CLAUDE_MONITOR_DIR="$HOME/.claude-monitor"
      SWIFTBAR_PLUGINS_DIR="$HOME/Library/Application Support/SwiftBar"

      # Colors
      GREEN='\\033[0;32m'
      BLUE='\\033[0;34m'
      YELLOW='\\033[1;33m'
      NC='\\033[0m'

      echo -e "${BLUE}🚀 ClaudeCode Monitor Setup${NC}"
      echo "=============================="
      echo

      # Create monitor directory
      mkdir -p "$CLAUDE_MONITOR_DIR"
      mkdir -p "$CLAUDE_MONITOR_DIR/lib"
      mkdir -p "$CLAUDE_MONITOR_DIR/scripts"

      # Copy files to runtime locations
      echo -e "${BLUE}📦 Installing runtime files...${NC}"
      cp "$CLAUDE_MONITOR_PREFIX/lib/status_manager.sh" "$CLAUDE_MONITOR_DIR/lib/"
      cp "$CLAUDE_MONITOR_PREFIX/scripts/swiftbar_manager.sh" "$CLAUDE_MONITOR_DIR/scripts/"
      cp "$CLAUDE_MONITOR_PREFIX/scripts/generate_settings.sh" "$CLAUDE_MONITOR_DIR/scripts/"
      chmod +x "$CLAUDE_MONITOR_DIR/lib/status_manager.sh"
      chmod +x "$CLAUDE_MONITOR_DIR/scripts/swiftbar_manager.sh"
      chmod +x "$CLAUDE_MONITOR_DIR/scripts/generate_settings.sh"

      # Install SwiftBar plugin
      echo -e "${BLUE}🔌 Installing SwiftBar plugin...${NC}"
      mkdir -p "$SWIFTBAR_PLUGINS_DIR"
      cp "$CLAUDE_MONITOR_PREFIX/plugins/claude_monitor.1s.sh" "$SWIFTBAR_PLUGINS_DIR/"
      chmod +x "$SWIFTBAR_PLUGINS_DIR/claude_monitor.1s.sh"

      # Update plugin to use correct status manager path
      sed -i '' "s|readonly STATUS_MANAGER=\\\".*\\\"|readonly STATUS_MANAGER=\\\"$CLAUDE_MONITOR_DIR/lib/status_manager.sh\\\"|" \\
          "$SWIFTBAR_PLUGINS_DIR/claude_monitor.1s.sh"

      # Configure ClaudeCode hooks
      echo -e "${BLUE}🔗 Configuring ClaudeCode hooks...${NC}"
      mkdir -p "$CLAUDE_CONFIG_DIR/hooks"
      cp "$CLAUDE_MONITOR_PREFIX/hooks/update_status.sh" "$CLAUDE_CONFIG_DIR/hooks/"
      chmod +x "$CLAUDE_CONFIG_DIR/hooks/update_status.sh"

      # Backup existing settings
      if [[ -f "$CLAUDE_CONFIG_DIR/settings.json" ]]; then
          backup_file="$CLAUDE_CONFIG_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
          echo -e "${YELLOW}⚠️  Backing up existing settings to: $backup_file${NC}"
          cp "$CLAUDE_CONFIG_DIR/settings.json" "$backup_file"
          echo "$backup_file" > "$CLAUDE_MONITOR_DIR/backup_path.txt"

          # Ask user about merge strategy
          echo
          echo "Existing ClaudeCode hooks detected!"
          echo "How should we handle existing hooks?"
          echo "1) Replace - Override existing hooks (recommended)"
          echo "2) Skip - Keep existing hooks (monitor won't work)"
          echo
          read -p "Choose option (1-2) [1]: " -n 1 -r
          echo

          case "${REPLY:-1}" in
              2)
                  echo -e "${YELLOW}Keeping existing hooks - monitor may not work${NC}"
                  ;;
              *)
                  echo -e "${BLUE}Updating hooks configuration...${NC}"
                  "$CLAUDE_MONITOR_DIR/scripts/generate_settings.sh" merge "$CLAUDE_CONFIG_DIR/settings.json" replace > /tmp/claude_settings_$$.json
                  mv /tmp/claude_settings_$$.json "$CLAUDE_CONFIG_DIR/settings.json"
                  echo -e "${GREEN}✅ Hooks configured${NC}"
                  ;;
          esac
      else
          echo -e "${BLUE}Creating new settings.json...${NC}"
          "$CLAUDE_MONITOR_DIR/scripts/generate_settings.sh" generate > "$CLAUDE_CONFIG_DIR/settings.json"
          echo -e "${GREEN}✅ Settings created${NC}"
      fi

      # Initialize sessions file
      if [[ ! -f "$CLAUDE_MONITOR_DIR/sessions.json" ]]; then
          echo '{}' > "$CLAUDE_MONITOR_DIR/sessions.json"
      fi

      echo
      echo -e "${GREEN}✅ Setup complete!${NC}"
      echo
      echo "📋 Next steps:"
      echo "  1. Start monitoring: claude-monitor start"
      echo "  2. Check status: claude-monitor status"
      echo "  3. View sessions: cat ~/.claude-monitor/sessions.json | jq"
      echo
      echo "🐛 Troubleshooting:"
      echo "  • Enable debug: export CLAUDE_MONITOR_DEBUG=1"
      echo "  • View logs: tail -f ~/.claude-monitor/debug.log"
      echo
    EOS

    chmod 0755, bin/"claude-monitor"
    chmod 0755, bin/"claude-monitor-setup"
  end

  def post_install
    ohai "ClaudeCode Monitor installed successfully!"
    puts
    puts "📦 Installation complete! Now run setup:"
    puts "  claude-monitor-setup"
    puts
    puts "This will:"
    puts "  • Configure ClaudeCode hooks"
    puts "  • Install SwiftBar plugin"
    puts "  • Set up monitoring system"
    puts
  end

  def caveats
    <<~EOS
      ⚠️  SwiftBar is required but must be installed separately:
        brew install --cask swiftbar

      After installing SwiftBar, complete the setup:
        claude-monitor-setup
        claude-monitor start

      The monitor will appear in your macOS menu bar.

      For more information, see:
        #{doc}/README.md
    EOS
  end

  test do
    # Test that the main script can execute
    assert_match "ClaudeCode Monitor", shell_output("#{prefix}/lib/status_manager.sh --help 2>&1", 0)
  end
end
