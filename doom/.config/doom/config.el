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

;; ============================================================
;; Fonts — BlexMono Nerd Font (IBM Plex Mono patched with Nerd Font glyphs)
;; ============================================================
;; GUI Emacs: set primary + symbol fonts directly
(setq doom-font (font-spec :family "BlexMono Nerd Font Mono" :size 14)
      doom-variable-pitch-font (font-spec :family "BlexMono Nerd Font" :size 14)
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
  (setq org-ellipsis " ▾"))

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
