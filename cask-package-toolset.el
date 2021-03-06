;;; cask-package-toolset.el --- Toolsettize your package   -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Adrien Becchis

;; Author: Adrien Becchis <adriean.khisbe@live.fr>
;; Created:  2015-05-14
;; Version: 0.6.6
;; Keywords: convenience, tools
;; Url: http://github.com/AdrieanKhisbe/cask-package-toolset.el
;; Package-Requires: ((emacs "24") (cl-lib "0.3") (s "1.6.1") (dash "1.8.0") (f "0.10.0") (commander "0.2.0") (ansi "0.1.0") (shut-up "0.1.0"))

;; This file is not part of GNU Emacs.

;;; Licence:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Setup Continuous integration for EmacsLisp without pain!
;;
;; Easily setup test and continous intergration to have even better
;; emacs libraries where it's more easy to contribute and build new features! :)

;;; Code:

(require 'cl-lib)
(require 's)
(require 'dash)
(require 'f)
(require 'commander)
(require 'ansi)
(require 'shut-up)

(when noninteractive
  (shut-up-silence-emacs))

(defvar cask-package-toolset-templates '("Makefile" ".gitignore" ".travis.yml")
  "List of templates supported by `cask-package-toolset'.")
;; §maybe: later replace with alist struct: option, category

(defvar cask-package-toolset-github-remote "origin"
  "Name of the Github remote.")

(defvar cask-package-toolset-github-repository nil
  "Name of the Github repository.")

(defvar cask-package-toolset-badge-syntax :markdown)

(defvar cask-package-toolset-template-dir (f-expand "templates" (f-dirname (f-this-file)))
  "Folder holding the package templates.")

(defvar cask-package-toolset-force nil
  "Forcing the install or not.")

;; §TODO: refactor with a struct: just link, and build from syntax
(defconst cask-package-toolset-badge-templates-alist
  '(
    (:travis . ((:html . "<a href=\"http://travis-ci.org/%s\"><img alt=\"Build Status\" src=\" https://travis-ci.org/%s.svg\"/></a>")
                (:markdown . "[![Build Status](https://travis-ci.org/%s.svg)](https://travis-ci.org/%s)")
                (:orgmode . "[[https://travis-ci.org/%s][file:https://travis-ci.org/%s.svg]]")))
    (:melpa . ((:html . "<a href=\"http://melpa.org/#/%s\"><img alt=\"MELPA\" src=\"http://melpa.org/packages/%s-badge.svg\"/></a>")
               (:markdown . "[![MELPA](http://melpa.org/packages/%s-badge.svg)](http://melpa.org/#/%s)")
               (:orgmode . "[[http://melpa.org/#/%s][file:http://melpa.org/packages/%s-badge.svg]]")))
    (:melpa-stable . ((:html . "<a href=\"http://stable.melpa.org/#/%s\"><img alt=\"MELPA Stable\" src=\"http://stable.melpa.org/packages/%s-badge.svg\"/></a>")
                      (:markdown . "[![MELPA stable](http://stable.melpa.org/packages/%s-badge.svg)](http://stable.melpa.org/#/%s)")
                      (:orgmode . "[[http://stable.melpa.org/#/%s][file:http://stable.melpa.org/packages/%s-badge.svg]]")))
    (:licence . ((:html . "<a href=\"http://www.gnu.org/licenses/gpl-3.0.html\"><img alt=\"Licence\" src=\"http://img.shields.io/:license-gpl3-blue.svg/\"></a>")
                 (:markdown . "[![License] (http://img.shields.io/:license-gpl3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0.html)")
                 (:orgmode . "[[http://www.gnu.org/licenses/gpl-3.0.html][http://img.shields.io/:license-gpl3-blue.svg]]")))
    (:gitter . ((:html . "<a href=\"https://gitter.im/%s\"><img alt=\"Join the chat\" src=\"https://badges.gitter.im/Join%%20Chat.svg\"></a>")
                (:markdown . "[![Join the chat](https://badges.gitter.im/Join%%20Chat.svg)](https://gitter.im/%s)")
                (:orgmode . "[[https://gitter.im/%s][file:https://badges.gitter.im/Join%%20Chat.svg]]")))
    (:coveralls . ((:html . "<a href=\"https://coveralls.io/r/%s\"><img alt=\"Coverage Status\" src=\"https://coveralls.io/repos/%s/badge.svg\"/></a>")
                   (:markdown . "[![Coverage Status](https://coveralls.io/repos/%s/badge.svg)](https://coveralls.io/r/%s)")
                   (:orgmode . "[[https://coveralls.io/r/%s][file:https://coveralls.io/repos/%s/badge.svg]]")))
    ;; note: %%20 for format protection. (prevent interpretation as format specifi)
    ;;
    (:github . ((:html . "<a href=\"\"><img alt=\"Tag Version\" src=\"https://img.shields.io/github/tag/%s.svg\"/></a>")
                (:markdown . "[![Tag Version](https://img.shields.io/github/tag/%s.svg)](https://github.com/%s/tags)")
                (:orgmode . "[[https://github.com/%s/tags][file:https://img.shields.io/github/tag/%s.svg]]")))
    )
  "Template string alist for the Badges.")
;; §maybe: replace with custom

(defun cask-package-toolset-badge-template (name syntax)
  "Return the template for NAME in specified SYNTAX.
Throw exception if non existing!"
  (let ((result (cdr (assoc syntax (assoc name cask-package-toolset-badge-templates-alist)))))
    (if result result (error "%s and %s are not valid template key" name syntax))))

(defun cask-package-toolset-set-github-repository (repo)
  "Set github REPO."
  ;; §todo: check real repo
  (setq cask-package-toolset-github-repository repo))

(defun cask-package-toolset-set-github-remote (remote)
  "Set github REMOTE."
  ;; §todo: check real remote
  (setq cask-package-toolset-github-remote remote))

(defun cask-package-toolset-set-badge-syntax (syntax)
  "Set badge SYNTAX."
  (if (-any? (lambda(s)(s-equals? s syntax)) '("html" "markdown" "orgmode"))
      (setq cask-package-toolset-badge-syntax (intern (s-concat ":" syntax)))
      (message (ansi-red (format "%s is not a syntax, keeping default" syntax)))))

(defun cask-package-toolset-set-force ()
  "Set force mode."
  (setq cask-package-toolset-force t))

(defun cask-package-toolset-install-template (template-name)
  "Install provided TEMPLATE-NAME."
  (if (cask-package-toolset-template-present-p template-name)
      (progn
        (warn "File %s is already existing. Skipping" template-name)
        ;; §TODO: force option
        nil)
    (progn (cask-package-toolset-copy-template template-name)
           t)))

(defun cask-package-toolset--template-path (template-name)
  "Return path for TEMPLATE-NAME."
  (f-expand template-name cask-package-toolset-template-dir))

(defun cask-package-toolset-template-present-p (template-name)
  "Return t if TEMPLATE-NAME is already present in current-dir."
  (f-exists? (f-expand template-name)))

(defun cask-package-toolset-copy-template (template-name &optional subfolder)
  "Copy specified TEMPLATE-NAME in current folder or specified SUBFOLDER."
  ;; §TODO: add force param? (see how to use a symbol anywhere?)
  (let ((template-file (cask-package-toolset--template-path template-name))
        (destination-file (f-expand template-name)))
    (unless (f-exists? template-file)
      (error "Template %s not found" template-name)) ; §todo: use real error.
    (if (f-exists? destination-file)
        (error "File already existing %s" destination-file)
      (f-copy template-file destination-file))))

(defun cask-package-toolset-install-test-template (package-name)
  "Install the test templates for the PACKAGE-NAME."
  ;; §see: force argument? (for now suppose ok)
  (let ((data `(("package-name" . ,package-name))))
    (f-mkdir "test")
    (f-write-text (cask-package-toolset-fill-template "test/test-helper.el" data)
                  last-coding-system-used
                  "test/test-helper.el")
    (f-write-text (cask-package-toolset-fill-template "test/package-test.el" data)
                  last-coding-system-used
                  (format "test/%s-test.el" package-name))
    (cask-package-toolset-copy-template ".ert-runner")))

(defun cask-package-toolset-fill-template (template-path data)
  "Return filled the template located at TEMPLATE-PATH populated with DATA."
  ;;; §maybe: add argument to retrieve what we need
  (let ((template-file (cask-package-toolset--template-path template-path)))
    (unless (f-exists? template-file)
      (error "Template %s not found" template-path))
    (s-format (f-read-text template-file) 'aget data)))

;; Project Property extractors
;; §todo: maybe: set as a variable
(defun cask-package-toolset-github-repository-name()
  (if cask-package-toolset-github-repository
      cask-package-toolset-github-repository
    (let ((remote-name
           (s-trim
             (shell-command-to-string
              (format "git config --get remote.%s.url"
                      cask-package-toolset-github-remote)))))
      (when (s-contains? "github" remote-name)
        (s-chop-suffix
         ".git"
         (if (s-starts-with? "git" remote-name)
             (nth 1 (s-split ":" remote-name)) ; git protocol
           (nth 1 (s-split ".com/" remote-name)))))))) ; http

(defun cask-package-toolset-github-url (repository-name)
  "Return the github url from REPOSITORY-NAME."
  (unless (s-blank? repository-name)
    (format "http://github.com/%s" repository-name)))

(defun cask-package-toolset-travis-url (repository-name)
  "Return the travis url from REPOSITORY-NAME."
  (unless (s-blank? repository-name)
    (format "http://travis-ci.org/%s" repository-name)))

(defun cask-package-toolset-project-name (repository-name)
  "Return the project name from REPOSITORY-NAME.

Note it remove enventual trailing .el"
  (unless (s-blank? repository-name)
    (s-chop-suffix ".el" (nth 1 (s-split "/" repository-name)))))

;; Fragment generator
(defun cask-package-toolset-melpa-recipe (repository-name)
  "Return a melpa recipe corresponding to the REPOSITORY-NAME."
  (unless (s-blank? repository-name)
    (format "(%s :fetcher github :repo \"%s\")"
            (cask-package-toolset-project-name repository-name)
            repository-name)))

;; §TODO: extract fun: KILL WITH GENERICITY
(defun cask-package-toolset-travis-badge (repository-name syntax)
  "Return a travis badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (format (cask-package-toolset-badge-template :travis syntax)
            repository-name repository-name)))

(defun cask-package-toolset-melpa-badge (repository-name syntax)
  "Return a melpa badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (let ((project-name (cask-package-toolset-project-name repository-name)))
      (format (cask-package-toolset-badge-template :melpa syntax)
              project-name project-name))))

(defun cask-package-toolset-melpa-stable-badge (repository-name syntax)
  "Return a melpa stable badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (let ((project-name (cask-package-toolset-project-name repository-name)))
      (format (cask-package-toolset-badge-template :melpa-stable syntax)
              project-name project-name))))
;; §maybe: badge for cask conventions -> SEE

(defun cask-package-toolset-gitter-badge (repository-name syntax)
  "Return a gitter  badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (format (cask-package-toolset-badge-template :gitter syntax) repository-name)))

(defun cask-package-toolset-licence-badge (syntax)
  "Return a licence in specified SYNTAX."
  (cask-package-toolset-badge-template :licence syntax))

(defun cask-package-toolset-coveralls-badge (repository-name syntax)
  "Return a gitter  badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (format (cask-package-toolset-badge-template :coveralls syntax)
            repository-name repository-name)))

(defun cask-package-toolset-github-tag-badge (repository-name syntax)
  "Return a gitter  badge corresponding to the REPOSITORY-NAME in specified SYNTAX."
  (unless (s-blank? repository-name)
    (format (cask-package-toolset-badge-template :github syntax)
            repository-name repository-name)))


;; Commands
(defun cask-package-toolset-install-all-templates ()
  "Install all the packages.  (from `cask-package-toolset-templates')."
  (-each cask-package-toolset-templates
    (lambda (template) (cask-package-toolset-install-template template))))

(defun cask-package-toolset-noop ()
  "Invite to specify a command."
  (message (ansi-blue "Give us a command. install for instance, or consult usage with help")))

(defun cask-package-toolset-print-github-remote()
  (message "%s" (cask-package-toolset-github-repository-name)))

(defun cask-package-toolset-print-melpa-recipe ()
  "Print Melpa Recipe."
  (let ((melpa-recipe (cask-package-toolset-melpa-recipe
                       (cask-package-toolset-github-repository-name))))
    (message (if (s-blank? melpa-recipe)
                 (ansi-red "We could not retrieve melpa recipe, specify the remote if origin does not refer to your github repository.")
               melpa-recipe))))

(defun cask-package-toolset-setup-test()
  "Install Ert tests if not yet existing"
  (let ((package-name (cask-package-toolset-project-name
                       (cask-package-toolset-github-repository-name))))
    (if (s-blank? package-name)
       (message (ansi-red "We could not retrieve project-name from github repo, specify the remote if origin does not refer to your github repository."))
        (if (or (not (f-exists? (f-expand "test")))
                cask-package-toolset-force)
            (progn
              (cask-package-toolset-install-test-template package-name)
              (message (ansi-green "Ert Scaffold files generated")))
          (message (ansi-red "Some test file already exist. If you want to erase them, add --force option"))))))

(defun cask-package-toolset-print-setup-coverage()
  "Install Ert tests if not yet existing"
  (let ((package-name (cask-package-toolset-project-name
                       (cask-package-toolset-github-repository-name))))
    (if (s-blank? package-name)
        (message (ansi-red "We could not retrieve project-name from github repo, specify the remote if origin does not refer to your github repository."))
      (message "%s" (cask-package-toolset-fill-template "undercover.el"
                                                        `(("package-name" . ,package-name)))))))

(defun cask-package-toolset-print-badges ()
  "Print Melpa Recipe."
  (let ((repository-name (cask-package-toolset-github-repository-name)))
    (if repository-name
        (progn
          (message "%s" (cask-package-toolset-travis-badge repository-name cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-coveralls-badge repository-name cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-melpa-badge repository-name cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-melpa-stable-badge repository-name cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-github-tag-badge repository-name cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-licence-badge cask-package-toolset-badge-syntax))
          (message "%s" (cask-package-toolset-gitter-badge repository-name cask-package-toolset-badge-syntax))
          ;; note: lost 30 min: Not enough arguments for format string... (for gitterbadge %% quot)
          )
      (message (ansi-red "We could not retrieve melpa recipe, specify the remote if origin does not refer to your github repository.")))))

(defun cask-package-toolset-print-status()
  "Print current status of the repository"
  (let ((file-status
         `(;; File/Name - Status - Reco if Nok
           ;; check installed templates.
           ,@(-map (lambda (file)(list file (f-exists? file) "You should run `package-toolset'"))
                   cask-package-toolset-templates)
           ;; check installed ert
           ("Ert Test" ,(f-directory? "test") "You should run `cask exec package-toolset setup-ert'")
           ;; check installed ecukes
           ("Ecukes Features" ,(and (f-directory? "features/step-definitions")
                                    (f-directory? "features/support"))
            "You should run `cask exec ecukes new'")
           )))
    (-each file-status
      (lambda (it)
        (message "- %s →   %s" (s-pad-right 28 " " (ansi-blue (car it))) (if (nth 1 it) (ansi-green "Ok") (ansi-red (nth 2 it))))))))

(commander
 (name "cask-package-toolset")
 (description "Toolsettize your emacs package")
 (config ".cask-package-toolset")
 (default cask-package-toolset-noop)

 (option "--github-repo <repo>, -g <repo>" cask-package-toolset-set-github-repository)
 (option "--remote <remote>, -r <remote>" cask-package-toolset-set-github-remote)
 (option "--syntax <syntax>, -s <syntax>" cask-package-toolset-set-badge-syntax)
 (option "--force, -f" cask-package-toolset-set-force)
 (option "--help, -h" commander-print-usage) ; §todo: option specific help

 (command "status" "CI status of your package" cask-package-toolset-print-status)
 (command "install" "Install basic template for CI" cask-package-toolset-install-all-templates)
 (command "setup" "Install basic template for CI" cask-package-toolset-install-all-templates)
 (command "setup-ert" "Setup ert test structure" cask-package-toolset-setup-test)
 (command "setup-undercover" "Print snippets of code to set up coverage" cask-package-toolset-print-setup-coverage)
 (command "badge" "Print badges to add to your READLE" cask-package-toolset-print-badges)
 (command "melpa-recipe" "Print recipe for melpa" cask-package-toolset-print-melpa-recipe)
 (command "git" "Print deduced github remote" cask-package-toolset-print-github-remote)
 (command "help" "Show usage information" commander-print-usage))


(provide 'cask-package-toolset)
;;; cask-package-toolset.el ends here
