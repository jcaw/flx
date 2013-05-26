;;; flx-ido.el --- flx integration for ido

;; this file is not part of Emacs

;; Copyright (C) 2013 Le Wang
;; Author: Le Wang
;; Maintainer: Le Wang
;; Description: flx integration for ido
;; Author: Le Wang
;; Maintainer: Le Wang

;; Created: Sun Apr 21 20:38:36 2013 (+0800)
;; Version: 0.1
;; Last-Updated:
;;           By:
;;     Update #: 49
;; URL:
;; Keywords:
;; Compatibility:

;;; Installation:

;; Add to your init file:
;;
;;     (require 'flx-ido)
;;     (ido-mode 1)
;;     (ido-everywhere 1)
;;     (flx-ido-mode 1)
;;
;;

;;; Commentary:

;;
;;
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;
;;; credit to Scott Frazer's blog entry here:http://scottfrazersblog.blogspot.com.au/2009/12/emacs-better-ido-flex-matching.html
;;;


;;; Code:

(eval-when-compile (require 'cl))
(require 'ido)
(require 'flx)

(unless (fboundp 'ido-delete-runs)
  (defun ido-delete-runs (list)
    "Delete consecutive runs of same item in list.
Comparison done with `equal'.  Runs may loop back on to the first
item, in which case, the ending items are deleted."
    (let ((tail list)
          before-last-run)
      (while tail
        (if (consp (cdr tail))
            (if (equal (car tail) (cadr tail))
                (setcdr tail (cddr tail))
              (setq before-last-run tail)
              (setq tail (cdr tail)))
          (setq tail (cdr tail))))
      (when (and before-last-run
                 (equal (car list) (cadr before-last-run)))
        (setcdr before-last-run nil)))
    list))

(defvar flx-ido-narrowed-matches-hash (make-hash-table :test 'equal))

(defun flx-ido-narrowed (query items)
  "Get the value from `flx-ido-narrowed-matches-hash' with the
  longest prefix match."
  (if (zerop (length query))
      (list t (nreverse items))
    (let ((query-key (flx-ido-key-for-query query))
          best-match
          exact
          res)
      (loop for key being the hash-key of flx-ido-narrowed-matches-hash
            do (when (and (>= (length query-key) (length key))
                          (eq t
                              (compare-strings query-key 0 (min (length query-key)
                                                                (length key))
                                               key 0 nil))
                          (or (null best-match)
                              (> (length key) (length best-match))))
                 (setq best-match key)
                 (when (= (length key)
                          (length query-key))
                   (setq exact t)
                   (return))))
      (setq res (cond (exact
                       (gethash best-match flx-ido-narrowed-matches-hash))
                      (best-match
                       (flx-ido-undecorate (gethash best-match flx-ido-narrowed-matches-hash)))
                      (t
                       (flx-ido-undecorate items))))
      (list exact res))))

(defun flx-ido-undecorate (strings)
  (flx-ido-decorate strings t))


(defun flx-ido-decorate (things &optional clear)
  (let ((decorate-count (min ido-max-prospects
                             (length things))))
    (nconc
     (loop for thing in things
           for i from 0 below decorate-count
           collect (if clear
                       (flx-propertize thing nil)
                     (flx-propertize (car thing) (cdr thing))))
     (if clear
         (nthcdr decorate-count things)
       (mapcar 'car (nthcdr decorate-count things))))))

(defun flx-ido-match-internal (query items)
  (let* ((matches (loop for item in items
                        for string = (if (consp item) (car item) item)
                        for score = (flx-score string query flx-file-cache)
                        if score
                        collect (cons item score)
                        into matches
                        finally return matches)))
    (flx-ido-decorate (ido-delete-runs
                       (sort matches
                             (lambda (x y) (> (cadr x) (cadr y))))))))

(defun flx-ido-key-for-query (query)
  (concat ido-current-directory query))

(defun flx-ido-cache (query items)
  (if (memq ido-cur-item '(file dir))
      items
    (puthash (flx-ido-key-for-query query) items flx-ido-narrowed-matches-hash)))

(defun flx-ido-match (query items)
  "Better sorting for flx ido matching."
  (destructuring-bind (exact res-items)
      (flx-ido-narrowed query items)
    (flx-ido-cache query (if exact
                             res-items
                           (flx-ido-match-internal query res-items)))))

(defadvice ido-exit-minibuffer (around flx-ido-undecorate activate)
  "Remove flx properties after."
  (let* ((obj (car ido-matches))
         (str (if (consp obj)
                  (car obj)
                obj)))
    (when (and flx-ido-mode str)
      (remove-text-properties 0 (length str)
                              '(face flx-highlight-face) str)))

  ad-do-it)

(defadvice ido-read-internal (around flx-ido-reset-hash activate)
  "Clear flx narrowed hash beforehand.

Remove flx properties after."
  (when flx-ido-mode
    (clrhash flx-ido-narrowed-matches-hash))
  ad-do-it)

(defadvice ido-set-matches-1 (around flx-ido-set-matches-1 activate)
  "Choose between the regular ido-set-matches-1 and my-ido-fuzzy-match"
  (if flx-ido-mode
      (setq ad-return-value (flx-ido-match ido-text (ad-get-arg 0)))
    ad-do-it))

;;;###autoload
(define-minor-mode flx-ido-mode
  "Toggle flx ido mode"
  :init-value nil
  :lighter ""
  :group 'ido
  :global t)

(provide 'flx-ido)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; flx-ido.el ends here

