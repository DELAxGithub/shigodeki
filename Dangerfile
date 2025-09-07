# Dangerfile for iOS Repository Guardrails
# CLAUDE_VERSION: v2025.01
# Enforces 300-line rule, small PR principle, and template compliance

# =============================
# CLAUDE.md GUARDRAIL ENFORCEMENT
# =============================

# Rule 1: File Length Enforcement (300-line rule)
# Check for files exceeding 300 lines (hard limit per CLAUDE.md)
def check_file_length
  long_files = []
  
  git.modified_files.each do |file|
    next unless file.end_with?('.swift')
    
    file_path = File.join(Dir.pwd, file)
    if File.exist?(file_path)
      line_count = File.readlines(file_path).count
      if line_count > 300
        long_files << "#{file}: #{line_count} lines (exceeds 300-line limit)"
      elsif line_count > 250
        warn("📏 File approaching size limit: #{file} has #{line_count} lines (warning at 250, error at 300)")
      end
    end
  end
  
  git.added_files.each do |file|
    next unless file.end_with?('.swift')
    
    file_path = File.join(Dir.pwd, file)
    if File.exist?(file_path)
      line_count = File.readlines(file_path).count
      if line_count > 300
        long_files << "#{file}: #{line_count} lines (exceeds 300-line limit)"
      elsif line_count > 250
        warn("📏 New file approaching size limit: #{file} has #{line_count} lines (warning at 250, error at 300)")
      end
    end
  end
  
  unless long_files.empty?
    fail("🚨 **300-Line Rule Violation**: The following files exceed the 300-line limit:\n\n" + 
         long_files.map { |f| "- #{f}" }.join("\n") + 
         "\n\n**Action Required**: Split these files according to CLAUDE.md guidelines before merging.")
  end
end

# Rule 2: Small PR Principle Enforcement
# Maximum 10 files and 1,000 lines of changes per CLAUDE.md
def check_pr_size
  total_files = git.modified_files.count + git.added_files.count + git.deleted_files.count
  
  if total_files > 10
    fail("🚨 **Small PR Violation**: This PR modifies #{total_files} files (limit: 10). " +
         "Split into smaller PRs focusing on single responsibility.")
  end
  
  total_additions = git.insertions
  total_deletions = git.deletions
  total_changes = total_additions + total_deletions
  
  if total_changes > 1000
    fail("🚨 **Large PR Violation**: This PR has #{total_changes} line changes (limit: 1,000). " +
         "Break down into smaller, focused PRs.")
  end
  
  # Warn if approaching limits
  if total_files > 7
    warn("⚠️ PR size warning: #{total_files} files modified (approaching 10-file limit)")
  end
  
  if total_changes > 750
    warn("⚠️ PR size warning: #{total_changes} line changes (approaching 1,000-line limit)")
  end
end

# Rule 3: PR Template Compliance Check
# Ensure all required sections are filled in the PR description
def check_template_compliance
  pr_body = github.pr_body || ""
  
  # Required checkboxes from template
  required_checks = [
    "CLAUDE.md v2025.01 読了",
    "1ファイル1責任/300行ルール遵守", 
    "小PR原則",
    "スコープ固定",
    "レポート整合性"
  ]
  
  missing_checks = []
  
  required_checks.each do |check|
    # Look for checked checkbox with the required text
    unless pr_body.include?("- [x]") && pr_body.include?(check)
      missing_checks << check
    end
  end
  
  unless missing_checks.empty?
    fail("🚨 **Template Compliance Violation**: Missing required checklist items:\n\n" +
         missing_checks.map { |check| "- [ ] #{check}" }.join("\n") + 
         "\n\nPlease complete all required items in the PR template.")
  end
  
  # Check for required sections
  required_sections = [
    "目的/責務（Why）",
    "変更概要（What）", 
    "スコープ固定（Scope Lock）",
    "ファイル行数チェック表"
  ]
  
  missing_sections = []
  required_sections.each do |section|
    unless pr_body.include?(section)
      missing_sections << section
    end
  end
  
  unless missing_sections.empty?
    fail("🚨 **Template Section Missing**: The following required sections are missing:\n\n" +
         missing_sections.map { |section| "- #{section}" }.join("\n") +
         "\n\nPlease use the complete PR template.")
  end
end

# Rule 4: Scope Lock Validation
# Check that rename/move operations are separated from logic changes
def check_scope_lock
  renamed_files = []
  modified_files = []
  
  git.modified_files.each do |file|
    # Simple heuristic: if file content changed significantly, it's likely logic change
    # This is a basic check - manual review still needed for complex cases
    
    # Check if this looks like a pure rename by examining commit message
    if github.pr_title.downcase.include?("rename") || 
       github.pr_title.downcase.include?("move") ||
       github.pr_body.downcase.include?("rename") ||
       github.pr_body.downcase.include?("move")
      renamed_files << file
    else
      modified_files << file
    end
  end
  
  if !renamed_files.empty? && !modified_files.empty?
    warn("⚠️ **Scope Lock Advisory**: This PR appears to mix file renames/moves with logic changes. " +
         "Consider separating into: 1) rename/move commit, 2) logic changes commit for easier review.")
  end
end

# Rule 5: Architecture Compliance
# Basic checks for proper iOS project structure
def check_ios_architecture
  # Check for proper separation of Views, Services, Components
  views_in_wrong_location = []
  services_in_wrong_location = []
  
  git.added_files.each do |file|
    next unless file.end_with?('.swift')
    
    if file.include?('View.swift') && !file.include?('Views/') && !file.include?('Components/')
      views_in_wrong_location << file
    end
    
    if file.include?('Service.swift') && !file.include?('Services/')
      services_in_wrong_location << file
    end
  end
  
  unless views_in_wrong_location.empty?
    warn("📁 **Architecture Advisory**: Consider moving View files to Views/ or Components/ folder:\n" +
         views_in_wrong_location.map { |f| "- #{f}" }.join("\n"))
  end
  
  unless services_in_wrong_location.empty?
    warn("📁 **Architecture Advisory**: Consider moving Service files to Services/ folder:\n" +
         services_in_wrong_location.map { |f| "- #{f}" }.join("\n"))
  end
end

# =============================
# EXECUTE ALL CHECKS
# =============================

# Core guardrail enforcement (will fail PR if violated)
check_file_length
check_pr_size
check_template_compliance

# Advisory checks (warnings only)
check_scope_lock
check_ios_architecture

# =============================
# POSITIVE REINFORCEMENT
# =============================

# Celebrate good practices
if git.insertions < 200 && git.deletions < 100 && (git.modified_files.count + git.added_files.count) <= 5
  message("✨ **Excellent PR Size**: Small, focused PR that's easy to review! 👏")
end

# Check if PR follows single responsibility
if github.pr_title.downcase.include?("refactor") && github.pr_title.include?("split")
  message("🏗️ **Great Refactoring**: Thank you for following the single responsibility principle!")
end

# =============================
# SUMMARY MESSAGE
# =============================

message("📋 **Guardrail Check Complete**\n\n" +
        "Files modified: #{git.modified_files.count + git.added_files.count}/10\n" +
        "Lines changed: #{git.insertions + git.deletions}/1,000\n" +
        "CLAUDE_VERSION: v2025.01")