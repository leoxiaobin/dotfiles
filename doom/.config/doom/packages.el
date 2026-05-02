;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; ============================================================
;; Theme
;; ============================================================
(package! catppuccin-theme)

;; Magit ships git-commit.el, but recent straight recipe resolution can ask for
;; git-commit as a standalone package while building Magit dependencies.
(package! git-commit
  :recipe (:host github :repo "magit/magit"
           :files ("lisp/git-commit.el" "lisp/git-commit-pkg.el")))

;; Visual polish for Org buffers. This changes display only; Org files remain
;; plain text with normal stars, drawers, tables, and checkboxes.
(package! org-modern)

;; Markdown reading/writing enhancements
(package! mixed-pitch)        ; variable-pitch prose + fixed-pitch code
(package! grip-mode)          ; GitHub-style markdown preview in browser

;; ============================================================
;; OPTIONAL: Future AI packages (all disabled)
;; Uncomment only if you want API-based AI inside Emacs.
;; These require API keys — see each package's docs first.
;; ============================================================
;; (package! gptel)
;; (package! aider :recipe (:host github :repo "tninja/aider.el"))
