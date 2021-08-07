(setq macro-opens '("#if" "#ifdef" "#ifndef"))
(setq macro-switch-branch '("#elif" "#else"))
(setq macro-closes '("#endif"))

(defun show-ifdefs ()
  (interactive)
  (let ((output (preprocessor-collect-accumulated-ifdefs-before (line-end-position))))
    (message (mapconcat 'identity (reverse output) (make-bold " AND ")))))

(defun preprocessor-collect-accumulated-ifdefs-before (point)
  (let* ((buffer (buffer-substring-no-properties (point-min) point))
         (lines (split-string buffer "\n"))
         (output (list))
         line trimmed-line match-found open-string switch-string close-string)
    (dolist (line lines output)
      (setq trimmed-line (string-trim line))

      ;; If we find a macro closing tag, pop its opener
      (setq match-found nil)
      (dolist (close-string macro-closes)
        (if (string-prefix-p close-string trimmed-line)
            (setq match-found t)))
      (if match-found (pop output))

      ;; If we find a branch-switching tag, modify the stored macro text
      (dolist (switch-string macro-switch-branch)
        (if (string-prefix-p switch-string trimmed-line)
            (let ((opener (pop output)))
              (push (concat (make-strikethrough opener) " " trimmed-line) output))))

      ;; If we find a macro opening tag, push it to the output stack
      (setq match-found nil)
      (dolist (open-string macro-opens)
        (if (string-prefix-p open-string trimmed-line)
            (setq match-found t)))
      (if match-found (push trimmed-line output)))
    output))

(setq preprocessor-collect-overlay nil)
(make-local-variable 'preprocessor-collect-overlay)

(defun preprocessor-collect-update-overlay-if-present ()
  (if preprocessor-collect-overlay
      (preprocessor-collect-overlay-ifdefs)))


(defun preprocessor-collect-overlay-ifdefs ()
  (interactive)
  (when (not preprocessor-collect-overlay)
    (setq preprocessor-collect-overlay (make-overlay (window-start) (window-start) ))
    (add-hook 'post-command-hook 'preprocessor-collect-update-overlay-if-present nil t))
  (let ((num-output-lines 0)
        (num-iterations 0)
        (output-stable nil)
        output cur-num-lines)
    (while (and (not output-stable) (< num-iterations 5))
      (setq num-iterations (+ num-iterations 1))
      (let ((start-pos (save-excursion (goto-char (window-start))
                                       (forward-line num-output-lines)
                                       (line-end-position))))
        (setq output (preprocessor-collect-accumulated-ifdefs-before start-pos))
        (setq cur-num-lines (length output))
        (if (= cur-num-lines num-output-lines)
            (setq output-stable t))
        (setq num-output-lines cur-num-lines)))
    (let ((overlay-end-point (save-excursion (goto-char (window-start))
                                            (forward-line (- num-output-lines 1))
                                            (+ (line-end-position) 1))))
      (if (= num-output-lines 0)  ; if there's nothing in the output, don't display the overlay
          (setq overlay-end-point (window-start)))
      (move-overlay preprocessor-collect-overlay (window-start) overlay-end-point)
      (let ((concatenated-output (concat (mapconcat 'identity (reverse output) "\n") "\n")))
        (overlay-put preprocessor-collect-overlay 'display
                     (propertize concatenated-output 'face '(:weight bold :background "#ebebeb")))))))

(defun preprocessor-collect-overlay-clear ()
  (interactive)
  (when preprocessor-collect-overlay
    (delete-overlay preprocessor-collect-overlay)
    (remove-hook 'post-command-hook 'preprocessor-collect-update-overlay-if-present t))
  (setq preprocessor-collect-overlay nil))

(defun preprocessor-collect-toggle-overlay-ifdefs ()
  (interactive)
  (if preprocessor-collect-overlay
      (preprocessor-collect-overlay-clear)
    (preprocessor-collect-overlay-ifdefs)))

(defun make-bold (s)
  (propertize s 'face '(:weight bold)))

(defun make-strikethrough (s)
  (propertize s 'face '(:strike-through t)))

(defun make-background-grey (s)
  (propertize s 'face '(:background "#ebebeb")))

(provide 'preprocessor-collect)
