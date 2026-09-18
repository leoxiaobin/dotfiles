;;; org-notebook.el --- Notebook regressions in an isolated HOME -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'org-capture)
(require 'org-agenda)

;; Read only our helpers, without loading Doom or the user's installed packages.
(with-temp-buffer
  (insert-file-contents "doom/.config/doom/config.el")
  (goto-char (point-min))
  (condition-case nil
      (while t
        (let ((form (read (current-buffer))))
          (when (and (eq (car-safe form) 'defun)
                     (memq (cadr form)
                           '(my/org-notebook-setup
                             my/org-display-math-newlines
                             my/hide-terminal-menu-bar)))
            (eval form t))))
    (end-of-file nil)))

(ert-deftest notebook-first-run-capture-agenda-and-refile ()
  ;; The Python runner supplies a fresh HOME. Do not pre-create any folders.
  (should-not (file-exists-p (expand-file-name "~/notes")))
  (my/org-notebook-setup)
  (dolist (dir '("research" "experiments" "engineering" "meetings"))
    (should (file-directory-p (expand-file-name dir org-directory))))
  (should-not (org-agenda-files))
  (should-not (file-exists-p org-default-notes-file))
  (let ((org-agenda-window-setup 'current-window))
    (org-agenda-list))
  ;; Exercise the actual Org capture writer, including absent target files.
  (dolist (key '("n" "t" "d" "e" "m" "p" "i"))
    (org-capture nil key)
    (insert (concat "probe-" key))
    (org-capture-finalize))
  (dolist (pair '(("inbox.org" . "probe-n")
                  ("inbox.org" . "TODO probe-t")
                  ("daily.org" . "probe-d")
                  ("experiments/log.org" . "probe-e")
                  ("meetings/log.org" . "probe-m")
                  ("engineering/coding-prompts.org" . "probe-p")
                  ("engineering/agent-instructions.org" . "probe-i")))
    (with-temp-buffer
      (insert-file-contents (expand-file-name (car pair) org-directory))
      (should (search-forward (cdr pair) nil t))))
  ;; A new destination must appear without rerunning setup. Root scratch files
  ;; and the retired ~/org workspace must not leak into the agenda.
  (dolist (file '("research/new.org" "test.org" "README.org"))
    (with-temp-file (expand-file-name file org-directory)
      (insert "* TODO Fixture\n")))
  (make-directory (expand-file-name "~/org") t)
  (with-temp-file (expand-file-name "~/org/old.org")
    (insert "* TODO Old task\n"))
  (let ((files (org-agenda-files))
        (destination (expand-file-name "research/new.org" org-directory)))
    (should (member destination files))
    (dolist (excluded '("test.org" "README.org" "../org/old.org"))
      (should-not (member (expand-file-name excluded org-directory) files)))
    (should (cl-some (lambda (target) (equal (nth 1 target) destination))
                     (org-refile-get-targets))))
  ;; Reapplying setup must not replace notebook content.
  (my/org-notebook-setup)
  (with-temp-buffer
    (insert-file-contents org-default-notes-file)
    (should (search-forward "probe-n" nil t))))

(ert-deftest notebook-display-math-indentation-and-wrapping ()
  (dolist (prefix '("" "  "))
    (with-temp-buffer
      (insert prefix "\\[\\]")
      (backward-char 2)
      (my/org-display-math-newlines "\\[" 'insert nil)
      (should (equal (buffer-string)
                     (concat prefix "\\[\n" prefix "\n" prefix "\\]")))
      (should (= (line-number-at-pos) 2))
      (should (= (current-column) (length prefix)))))
  (with-temp-buffer
    (insert "\\[x\\]")
    (my/org-display-math-newlines "\\[" 'wrap nil)
    (should (equal (buffer-string) "\\[x\\]"))))

(ert-deftest notebook-menu-bar-is-terminal-only ()
  (let (changes)
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (frame) (eq frame 'gui)))
              ((symbol-function 'set-frame-parameter)
               (lambda (frame parameter value)
                 (push (list frame parameter value) changes))))
      (my/hide-terminal-menu-bar 'gui)
      (should-not changes)
      (my/hide-terminal-menu-bar 'tty)
      (should (equal changes '((tty menu-bar-lines 0)))))))

(ert-run-tests-batch-and-exit)
