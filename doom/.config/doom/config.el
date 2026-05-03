;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ============================================================
;; Identity (uncomment and set if needed for GPG, email, etc.)
;; ============================================================
;; (setq user-full-name "Your Name"
;;       user-mail-address "you@example.com")

;; ============================================================
;; Core settings
;; ============================================================
(setq doom-theme 'catppuccin)
(setq display-line-numbers-type t)
(setq org-directory "~/org/")
(setq global-auto-revert-non-file-buffers t)
(global-auto-revert-mode 1)

;; Emacs daemon/client support. Skip this in noninteractive commands such as
;; `doom sync' so package operations do not start a server.
(unless noninteractive
  (require 'server)
  (unless (server-running-p)
    (server-start)))

;; ============================================================
;; Fonts — BlexMono Nerd Font (IBM Plex Mono patched with Nerd Font glyphs)
;; ============================================================
;; GUI Emacs: set primary + symbol fonts directly
(setq doom-font (font-spec :family "BlexMono Nerd Font Mono" :size 16)
      doom-variable-pitch-font (font-spec :family "BlexMono Nerd Font" :size 16)
      doom-symbol-font (font-spec :family "Symbols Nerd Font Mono"))
;; Terminal Emacs: set your terminal emulator's font to
;; "BlexMono Nerd Font Mono" for icons to work.

;; ============================================================
;; Performance
;; ============================================================
;; Increase read chunk size for LSP — default 4KB is too small
(setq read-process-output-max (* 1024 1024)) ; 1MB

;; Only check Git, not SVN/Hg — each backend probes on every file open
(setq vc-handled-backends '(Git))

;; Don't check vc status on remote/TRAMP files
(setq vc-ignore-dir-regexp
      (format "\\(%s\\)\\|\\(%s\\)"
              vc-ignore-dir-regexp
              tramp-file-name-regexp))

;; ============================================================
;; Which-key (faster discovery of keybindings)
;; ============================================================
(after! which-key
  (setq which-key-idle-delay 0.3))

;; ============================================================
;; Vterm & Terminal
;; ============================================================
(after! vterm
  (setq vterm-max-scrollback 10000)
  (setq vterm-shell (or (getenv "SHELL") shell-file-name))
  (setq vterm-kill-buffer-on-exit t)
  ;; Don't let evil hijack vterm keybindings
  (setq vterm-keymap-exceptions '("C-c" "C-x" "C-g" "M-x" "C-u" "C-h")))

;; ============================================================
;; AI CLI Integration — terminal-based, no API keys
;; ============================================================
;; Core helper: open a project-scoped vterm, optionally running a CLI command.
;; Handles TRAMP, missing executables, and project-scoped buffer reuse.
(defun my/vterm-in-project (name &optional cmd)
  "Open a named vterm buffer at the project root.
NAME is used to build the buffer name (scoped per project).
CMD, if non-nil, is an executable to run after the shell starts.
Reuses an existing buffer if one exists for this project+name."
  (require 'vterm nil t)
  (unless (fboundp 'vterm)
    (user-error "vterm is not available — enable it in init.el"))
  (let* ((root (or (doom-project-root) default-directory))
         (project-label (file-name-nondirectory (directory-file-name root)))
         (buf-name (format "*vterm:%s@%s*" name project-label)))
    ;; Guard against TRAMP remotes
    (when (file-remote-p root)
      (user-error "AI CLI commands are not supported over TRAMP remotes"))
    ;; Check executable exists before launching
    (when (and cmd (not (executable-find cmd)))
      (user-error "Executable '%s' not found in PATH" cmd))
    (let ((existing (get-buffer buf-name)))
      (if (and existing (buffer-live-p existing))
          (pop-to-buffer existing)
        (let ((default-directory root)
              (vterm-buffer-name buf-name))
          (vterm)
          (when cmd
            ;; Small delay to let the shell initialize
            (run-at-time 0.3 nil
                         (lambda (buf command)
                           (when (buffer-live-p buf)
                             (with-current-buffer buf
                               (vterm-send-string command)
                               (vterm-send-return))))
                         (get-buffer buf-name) cmd)))))))

(defun my/open-claude-code ()
  "Open Claude Code CLI in the current project root."
  (interactive)
  (my/vterm-in-project "claude" "claude"))

(defun my/open-codex ()
  "Open Codex CLI in the current project root."
  (interactive)
  (my/vterm-in-project "codex" "codex"))

(defun my/open-copilot-cli ()
  "Open Copilot CLI in the current project root."
  (interactive)
  (my/vterm-in-project "copilot" "copilot"))

(defun my/open-ai-terminal ()
  "Open a plain terminal in the current project root."
  (interactive)
  (my/vterm-in-project "ai-term"))

;; ============================================================
;; Keybindings — SPC a for AI terminal workflows
;; ============================================================
;; Clear any existing SPC a binding so it can become a prefix key
(after! general
  (define-key doom-leader-map "a" nil))
(map! :leader
      (:prefix ("a" . "AI terminals")
       :desc "AI terminal"    "a" #'my/open-ai-terminal
       :desc "Claude Code"    "c" #'my/open-claude-code
       :desc "Codex CLI"      "x" #'my/open-codex
       :desc "Copilot CLI"    "p" #'my/open-copilot-cli))

;; ============================================================
;; Org-mode — prompts, notes, experiment logs
;; ============================================================
(after! org
  (setq org-capture-templates
        '(("n" "Quick note" entry
           (file+headline "inbox.org" "Notes")
           "* %?\n%U\n" :empty-lines 1)

          ("p" "Coding prompt" entry
           (file+headline "coding-prompts.org" "Prompts")
           "* %?\n%U\n#+begin_src\n\n#+end_src\n" :empty-lines 1)

          ("i" "Agent instruction" entry
           (file+headline "agent-instructions.org" "Instructions")
           "* %?\n%U\n" :empty-lines 1)

          ("e" "Experiment log" entry
           (file+headline "experiments.org" "Log")
           "* %? :experiment:\n%U\n** Goal\n\n** Setup\n\n** Result\n\n** Notes\n"
           :empty-lines 1)))

  ;; Org-mode niceties
  (setq org-log-done 'time)
  (setq org-startup-folded 'content)
  (setq org-ellipsis " ▾")
  ;; Fold stars: default level 3+ uses ⯈/⯆ which many terminal fonts lack.
  ;; Use only common triangle glyphs (▶▷▸▹▾ are in BlexMono Nerd Font).
  (setq org-modern-fold-stars
        '(("▶" . "▼") ("▷" . "▽") ("▸" . "▾") ("▹" . "▿") ("▪" . "▫")))
  ;; Table rendering: pixel borders only work in GUI; disable in terminal.
  (if (display-graphic-p)
      (setq org-modern-table t
            org-modern-table-vertical 1
            org-modern-table-horizontal 0.2)
    (setq org-modern-table nil))
  (set-face-attribute 'org-table nil :foreground "#89b4fa")
  (add-hook 'org-mode-hook #'org-modern-mode))

;; ============================================================
;; Markdown — editing, reading, and preview
;; ============================================================
(after! markdown-mode
  ;; Syntax highlight fenced code blocks
  (setq markdown-fontify-code-blocks-natively t)
  ;; Soft-wrap lines for comfortable reading
  (add-hook 'markdown-mode-hook #'visual-line-mode)
  ;; Mixed-pitch: variable-pitch for prose, fixed-pitch for code/tables
  (add-hook 'markdown-mode-hook #'mixed-pitch-mode)
  ;; Distinct heading colors (Catppuccin Mocha palette)
  (custom-set-faces!
    '(markdown-header-face-1 :weight bold :foreground "#cba6f7")
    '(markdown-header-face-2 :weight bold :foreground "#89b4fa")
    '(markdown-header-face-3 :weight bold :foreground "#a6e3a1")
    '(markdown-header-face-4 :weight bold :foreground "#f9e2af")
    '(markdown-header-face-5 :weight bold :foreground "#f5c2e7")
    '(markdown-header-face-6 :weight bold :foreground "#94e2d5")))

;; Mixed-pitch — keep code in monospace, prose in variable-pitch
(after! mixed-pitch
  (setq mixed-pitch-set-height t))

;; Grip-mode — GitHub-flavored markdown preview in browser
;; Requires: pip install grip (or pipx install grip)
(after! grip-mode
  (setq grip-preview-use-webkit nil)  ; use external browser
  (setq grip-sleep-time 2))           ; reduce API calls

;; ============================================================
;; Magit — central to reviewing AI-generated diffs
;; ============================================================
(after! magit
  ;; Word-level diff highlighting for better AI diff review
  (setq magit-diff-refine-hunk 'all)
  ;; Don't prompt to save buffers before running magit
  (setq magit-save-repository-buffers 'dontask)
  ;; Skip gravatars for speed
  (setq magit-revision-show-gravatars nil))

;; ============================================================
;; LSP — minimal noise, no formatting conflicts
;; ============================================================
(after! lsp-mode
  ;; Reduce UI noise
  (setq lsp-headerline-breadcrumb-enable nil)
  (setq lsp-modeline-code-actions-enable nil)
  (setq lsp-signature-auto-activate nil)
  ;; Don't let LSP fight AI tools or external formatters
  (setq lsp-enable-on-type-formatting nil)
  (setq lsp-enable-indentation nil)
  ;; Keep useful features
  (setq lsp-enable-symbol-highlighting t)
  (setq lsp-modeline-diagnostics-enable t)
  ;; Performance: increase idle delay to avoid blocking on every keystroke
  (setq lsp-idle-delay 0.7)
  ;; Don't watch too many files — large repos can stall file-open
  (setq lsp-enable-file-watchers nil)
  ;; Don't log everything — reduces IPC overhead
  (setq lsp-log-io nil))

(after! lsp-ui
  ;; Sideline and doc popups can be noisy — disable by default
  (setq lsp-ui-sideline-enable nil)
  (setq lsp-ui-doc-enable nil))

;; ============================================================
;; Treemacs — project drawer
;; ============================================================
(after! treemacs
  (setq treemacs-width 30)
  (setq treemacs-position 'left)
  ;; 'simple' avoids expensive git shell-outs on every file change
  (setq +treemacs-git-mode 'simple))

;; ============================================================
;; Flycheck — delay syntax checks to avoid blocking file-open
;; ============================================================
(after! flycheck
  (setq flycheck-idle-change-delay 1.5)
  (setq flycheck-check-syntax-automatically '(save idle-change mode-enabled)))

;; ============================================================
;; mu4e — Gmail client via mbsync + OAuth2
;; ============================================================
(after! mu4e
  (setq mu4e-maildir "~/Mail"
        mu4e-get-mail-command "SASL_PATH=/opt/homebrew/lib/sasl2 mbsync -a"
        mu4e-update-interval 300  ; auto-sync every 5 minutes
        mu4e-index-update-in-background t)

  ;; Gmail folder mapping
  (setq mu4e-sent-folder   "/gmail/[Gmail]/Sent Mail"
        mu4e-drafts-folder "/gmail/[Gmail]/Drafts"
        mu4e-trash-folder  "/gmail/[Gmail]/Trash"
        mu4e-refile-folder "/gmail/[Gmail]/All Mail")

  ;; Don't save to Sent — Gmail does this server-side
  (setq mu4e-sent-messages-behavior 'delete)

  ;; Send mail via msmtp
  (setq sendmail-program "msmtp"
        send-mail-function #'smtpmail-send-it
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-send-mail-function #'message-send-mail-with-sendmail)

  ;; Identity
  (setq mu4e-compose-signature "Bin Xiao")

  ;; Headers columns (override Doom's default which includes :account-stripe
  ;; that requires multi-account context config)
  (setq mu4e-headers-fields
        '((:human-date . 12) (:flags . 6) (:from-or-to . 25) (:subject)))

  ;; Show inline images in HTML emails (GUI Emacs only)
  (when (display-graphic-p)
    (setq gnus-inhibit-images nil
          gnus-blocked-images nil
          mm-text-html-renderer 'shr))

  ;; Open links in eww (Emacs built-in browser)
  (setq browse-url-browser-function #'eww-browse-url)

  ;; Bookmarks for quick access
  (setq mu4e-bookmarks
        '((:name "Unread"    :query "flag:unread AND NOT flag:trashed" :key ?u)
          (:name "Today"     :query "date:today..now" :key ?t)
          (:name "This week" :query "date:7d..now" :key ?w)
          (:name "Flagged"   :query "flag:flagged" :key ?f))))

;; Open mu4e with SPC o m
(map! :leader
      :desc "Email (mu4e)" "o m" #'mu4e)

;; ============================================================
;; OPTIONAL: Future AI packages (all disabled)
;; Uncomment only if you want API-based AI inside Emacs.
;; These require API keys — see each package's docs first.
;; ============================================================
;; (use-package! gptel
;;   :defer t
;;   :config
;;   (setq gptel-default-mode 'org-mode))
;;
;; (use-package! aider
;;   :defer t)
