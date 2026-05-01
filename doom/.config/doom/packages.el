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

;; ============================================================
;; OPTIONAL: Future AI packages (all disabled)
;; Uncomment only if you want API-based AI inside Emacs.
;; These require API keys — see each package's docs first.
;; ============================================================
;; (package! gptel)
;; (package! aider :recipe (:host github :repo "tninja/aider.el"))
