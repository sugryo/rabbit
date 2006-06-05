;;; -*- mode: Emacs-Lisp; indent-tabs-mode: nil -*-
;;; rabbit-mode.el
;;  Emacs major mode for Rabbit
;;; Copyright (c) 2006 Atsushi TAKEDA <tkdats@kono.cis.iwate-u.ac.jp>
;;; $Date$

(require 'cl)
(require 'rd-mode)

(defvar rabbit-mode-hook nil
  "Hooks run when entering `rabbit-mode' major mode")
(defvar rabbit-command "rabbit")
(defvar rabbit-output-buffer nil)
(defvar rabbit-author "Author")
(defvar rabbit-institution "Institution")
(defvar rabbit-theme "rabbit")

(defvar rabbit-title-template
"= %s

: author
   %s
: institution
   %s
: theme
   %s
\n")

(defvar rabbit-slide-template
"= %s
\n")

(defvar rabbit-heading-face 'font-lock-keyword-face)
(defvar rabbit-emphasis-face 'font-lock-function-name-face)
(defvar rabbit-verbatim-face 'font-lock-function-name-face)
(defvar rabbit-term-face 'font-lock-function-name-face)
(defvar rabbit-footnote-face 'font-lock-function-name-face)
(defvar rabbit-link-face 'font-lock-function-name-face)
(defvar rabbit-code-face 'font-lock-function-name-face)
(defvar rabbit-description-face 'font-lock-constant-face)
(defvar rabbit-comment-face 'font-lock-comment-face)
(defvar rabbit-keyboard-face 'font-lock-function-name-face)
(defvar rabbit-variable-face 'font-lock-function-name-face)
(defvar rabbit-font-lock-keywords
  (list
   '("^= .*$"
     0 rabbit-heading-face)
   '("^==+ .*$"
     0 rabbit-comment-face)
   '("((\\*[^*]*\\*+\\([^)*][^%]*\\*+\\)*))"    ; ((* ... *))
     0 rabbit-emphasis-face)
   '("((%[^%]*%+\\([^)%][^%]*%+\\)*))"      ; ((% ... %))
     0 rabbit-keyboard-face)
   '("((|[^|]*|+\\([^)|][^|]*|+\\)*))"      ; ((| ... |))
     0 rabbit-variable-face)
   '("(('[^']*'+\\([^)'][^']*'+\\)*))"      ; ((' ... '))
     0 rabbit-verbatim-face)
   '("((:[^:]*:+\\([^):][^:]*:+\\)*))"      ; ((: ... :))
     0 rabbit-term-face)
   '("((-[^-]*-+\\([^)-][^-]*-+\\)*))"      ; ((- ... -))
     0 rabbit-footnote-face)
   '("((<[^>]*>+\\([^)>][^>]*>+\\)*))"      ; ((< ... >))
     0 rabbit-link-face)
   '("(({[^}]*}+\\([^)}][^}]*}+\\)*))"      ; (({ ... }))
     0 rabbit-code-face)
   '("^:.*$"
     0 rd-description-face)
   '("^#.*$"
      0 rabbit-comment-face)
   ))

(defvar rabbit-block-indent-size 2)

(defvar rabbit-image-size-unit-table
  '(("relative")
    ("normalized")
    ("pixel")))

(defvar rabbit-image-size-unit-history nil)

(define-derived-mode rabbit-mode rd-mode "Rabbit"
  (setq-default rabbit-running nil)
  (make-variable-buffer-local 'rabbit-running)
  (setq comment-start "#")
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '((rabbit-font-lock-keywords) t nil))
  (make-local-variable 'font-lock-keywords)
  (setq font-lock-keywords rabbit-font-lock-keywords)
  (rabbit-setup-keys)
  (run-hooks 'rabbit-mode-hook))

;;; interactive

(defun rabbit-run-rabbit ()
  "Emacs major mode for rabbit."
  (interactive)
  (let ((filename (rabbit-buffer-filename))
	(outbuf (rabbit-output-buffer)))
    (set-buffer outbuf)
    (if rabbit-running
	(error "Rabbit is already running.")
      (progn
	(setq rabbit-running t)
	(start-process "Rabbit" outbuf rabbit-command filename)
	(set-process-sentinel (get-buffer-process outbuf) 'rabbit-sentinel)))))

;;; insert functions

(defun rabbit-insert-title-template (rabbit-title)
  "insert a title template."
  (interactive "spresentation's title:")
  (save-excursion (insert (format rabbit-title-template
				  rabbit-title
				  rabbit-author
				  rabbit-institution
				  rabbit-theme)))
  (forward-line 9))

(defun rabbit-insert-image-template (file)
  "insert a image template."
  (interactive "fimage file: ")
  (rabbit-insert-image-template-real file (rabbit-read-size-unit)))

(defun rabbit-insert-image-template-default (file)
  "insert a image template with default image size unit."
  (interactive "fimage file: ")
  (rabbit-insert-image-template-real file))


(defun rabbit-insert-slide (rabbit-slide-title)
  "insert a slide."
  (interactive "sslide title: ")
  (save-excursion (insert (format rabbit-slide-template
                                  rabbit-slide-title)))
  (forward-line 2))

;;; move functions

(defun rabbit-next-slide ()
  "move to next slide."
  (interactive)
  (forward-line 1)
  (re-search-forward "^= " nil t)
  (goto-char (match-beginning 0)))

(defun rabbit-previous-slide ()
  "move to previous slide."
  (interactive)
  (re-search-backward "^= " nil t)
  (goto-char (match-beginning 0)))

;;; private

(defun rabbit-setup-keys ()
  "define default key bindings."
  (define-key rabbit-mode-map "\C-c\C-r" 'rabbit-run-rabbit)
  (define-key rabbit-mode-map "\C-c\C-t" 'rabbit-insert-title-template)
  (define-key rabbit-mode-map "\C-c\C-i" 'rabbit-insert-image-template-default)
  (define-key rabbit-mode-map "\C-ci" 'rabbit-insert-image-template)
  (define-key rabbit-mode-map "\C-c\C-s" 'rabbit-insert-slide)
  (define-key rabbit-mode-map "\M-n" 'rabbit-next-slide)
  (define-key rabbit-mode-map "\M-p" 'rabbit-previous-slide))

(defun rabbit-read-property (key)
  "read `key' value from minibuf and return string as \"key = value\"
format if value is specified, otherwise return \"\"."
  (let ((value (read-from-minibuffer (concat key ": "))))
    (if (string-equal value "")
        ""
      (concat key " = " value))))

(defun rabbit-block-indent (string)
  (let ((indent ""))
    (dotimes (i rabbit-block-indent-size (concat indent string))
      (setq indent (concat indent " ")))))

(defun rabbit-read-block-property (key)
  "read `key' value from minibuf and return string as \"key = value\"
format if value is specified, otherwise return \"\"."
  (let ((property (rabbit-read-property key)))
    (if (string-equal property "")
        ""
      (rabbit-block-indent (concat "# " property)))))

(defun rabbit-buffer-filename ()
  "return file name relating current buffer."
  (or (buffer-file-name)
      (error "This buffer is empty buffer.")))

(defun rabbit-sentinel (proc state)
  (set-buffer (process-buffer proc))
  (setq rabbit-running nil))

(defun rabbit-output-buffer ()
  "return buffer for rabbit output."
  (let* ((bufname (concat "*Rabbit<"
			  (file-relative-name (rabbit-buffer-filename))
			  ">*"))
	 (buf (get-buffer-create bufname)))
    buf))

(defun rabbit-default-image-size-unit ()
  (caar rabbit-image-size-unit-table))

(defun rabbit-read-size-unit ()
  "read what unit use for image size."
  (completing-read "image size unit: "
		   rabbit-image-size-unit-table
                   nil t nil
                   'rabbit-image-size-unit-history
                   (rabbit-default-image-size-unit)))

(defun rabbit-filter (predicate lst)
  (let ((result '()))
    (dolist (item lst (reverse result))
      (unless (funcall predicate item)
        (setq result (cons item result))))))

(defun rabbit-not-empty-string (string)
  (and string (not (string-equal string ""))))

(defun rabbit-join-without-empty-string (strings separator)
  (let ((result "")
        (not-empty-strings (rabbit-filter
                            '(lambda (string)
                               (not (rabbit-not-empty-string string)))
                            strings)))
    (if (null not-empty-strings)
        ""
      (dolist (string (cdr not-empty-strings)
                      (concat (car not-empty-strings) result))
        (setq result (concat result separator string))))))

(defun rabbit-insert-image-template-real (filename &optional unit)
  "insert a image template."
  (insert (concat
           (rabbit-join-without-empty-string
            `(,(rabbit-block-indent "# image")
              ,(rabbit-block-indent (concat "# src = "
                                            (file-relative-name filename)))
              ,(rabbit-read-block-property "caption")
              ,@(rabbit-read-size-value
                 (or unit (rabbit-default-image-size-unit))))
            "\n")
           "\n")))

(defun rabbit-read-size-value (unit)
  "return strings that specify image size."
  (let ((prefix (if (string-equal unit "pixel")
                    ""
                  (concat unit "_"))))
    (mapcar '(lambda (key)
               (rabbit-read-block-property (concat prefix key)))
            '("width" "height"))))

(provide 'rabbit-mode)