(require 'ert)
(require 'cl-lib)
(require 'csharp-mode)

;;; test-helper functions

(defun move-to-line-after (text)
  (search-forward text)
  (move-beginning-of-line 1)
  (forward-line 1))

(defun get-current-line-contents ()
  (let* ((start)
         (end))
    (move-beginning-of-line 1)
    (setq start (point))
    (move-end-of-line 1)
    (setq end (point))
    (buffer-substring start end)))

;;; actual tests

(ert-deftest activating-mode-doesnt-cause-failure ()
  (with-temp-buffer
    (csharp-mode)
    (should
     (equal 'csharp-mode major-mode))))

(defvar debug-res nil)

(ert-deftest fontification-of-literals-detects-end-of-strings ()
  ;; this test needs a double which also writes and generates the actual
  ;; test-content itself by inserting into a new temp buffer.
  (let* ((buffer (find-file-read-only "test-files/fontification-test.cs")))
    ;; double-ensure mode is active
    (csharp-mode)
    (if (fboundp 'font-lock-ensure)
        (font-lock-ensure))
    (goto-char (point-min))
    (let* ((buffer1)
           (buffer2))
      ;; get reference string
      (move-to-line-after "Literal1")
      (setq buffer1 (get-current-line-contents))

      ;; get verification string
      (move-to-line-after "Literal2")
      (setq buffer2 (get-current-line-contents))

      ;; check equality
      (should
       (equal-including-properties buffer1 buffer2)))))

(ert-deftest fontification-of-compiler-directives ()
  (let* ((buffer (find-file-read-only "test-files/fontification-test-compiler-directives.cs")))
    ;; double-ensure mode is active
    (csharp-mode)
    (if (fboundp 'font-lock-ensure)
        (font-lock-ensure))
    (goto-char (point-min))
    (let* ((reference)
           (v1)
           (t1)
           (t2))
      ;; get reference string
      (move-to-line-after "reference")
      (setq reference (get-current-line-contents))

      ;; get verification string
      (move-to-line-after "v1")
      (setq v1 (get-current-line-contents))

      ;; get test-case1
      (move-to-line-after "t1")
      (setq t1 (get-current-line-contents))

      ;; get test-case2
      (move-to-line-after "t2")
      (setq t2 (get-current-line-contents))

      ;; check equality
      (setq debug-res (list reference v1 t1 t2))
      (should (and
               (equal-including-properties reference v1)
               (equal-including-properties reference t1)
               (equal-including-properties reference t2))))))

(defun list-repeat-once (mylist)
  (append mylist mylist))

(ert-deftest build-warnings-and-errors-are-parsed ()
  (dolist (test-case
           `(("./test-files/msbuild-warning.txt" ,csharp-compilation-re-msbuild-warning 8
              ,(list-repeat-once
                '("Class1.cs"
                  "Folder\\Class1.cs"
                  "Program.cs"
                  "Program.cs")))
             ("./test-files/msbuild-error.txt" ,csharp-compilation-re-msbuild-error 2
              ,(list-repeat-once
                '("Folder\\Class1.cs")))
             ("./test-files/msbuild-concurrent-warning.txt" ,csharp-compilation-re-msbuild-warning 2
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/msbuild-concurrent-error.txt" ,csharp-compilation-re-msbuild-error 2
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/msbuild-square-brackets.txt" ,csharp-compilation-re-msbuild-error 6
              ,(list-repeat-once
                '("Properties\\AssemblyInfo.cs"
                  "Program.cs"
                  "Program.cs")))
             ("./test-files/msbuild-square-brackets.txt" ,csharp-compilation-re-msbuild-warning 2
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/xbuild-warning.txt" ,csharp-compilation-re-xbuild-warning 10
              ,(list-repeat-once
                '("/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Class1.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Folder/Class1.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs")))
             ("./test-files/xbuild-error.txt" ,csharp-compilation-re-xbuild-error 2
              ,(list-repeat-once
                '("/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Folder/Class1.cs")))
             ("./test-files/devenv-error.txt" ,csharp-compilation-re-xbuild-error 3
              ,(list-repeat-once
                '("c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"
                  "c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"
                  "c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp")))
             ("./test-files/devenv-error.txt" ,csharp-compilation-re-xbuild-warning 1
              ,(list-repeat-once
                '("c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp")))
             ("./test-files/devenv-mixed-error.txt" ,csharp-compilation-re-xbuild-error 3
              ,(list-repeat-once
                '("c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp"
                  "c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp"
                  "c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp")))
             ))

    (let* ((file-name (car test-case))
           (regexp    (cadr test-case))
           (times     (cl-caddr test-case))
           (matched-file-names (cl-cadddr test-case))
           (find-file-hook '()) ;; avoid vc-mode file-hooks when opening!
           (buffer (find-file-read-only file-name)))
      (message (concat "Testing compilation-log: " file-name))
      (dotimes (number times)
        (let* ((expected (nth number matched-file-names)))
          (message (concat "- Expecting match: " expected))
          (re-search-forward regexp)
          (should
           (equal expected (match-string 1)))))
      (kill-buffer buffer))))

(ert-deftest imenu-parsing-supports-default-values ()
  (dolist (test-case
           '(;; should support bools
             ("(bool a, bool b = true)"                  "(bool, bool)")
             ("(bool a=true, bool b)"                    "(bool, bool)")
             ;; should support strings
             ("(string a, string b = \"quoted string\")" "(string, string)")
             ("(string a = \"quoted string\", string b)" "(string, string)")
             ;; should support chars
             ("(char a, char b = 'b')"                   "(char, char)")
             ("(char a = 'a', char b)"                   "(char, char)")
             ;; should support self-object-access
             ("(object o = Const)"                       "(object)")
             ;; should support other-object-access
             ("(object o = ConstObject.Const)"           "(object)")
             ))
    (let* ((test-value     (car test-case))
           (expected-value (cadr test-case))
           (result         (csharp--imenu-remove-param-names-from-paramlist test-value)))
      (should (equal expected-value result)))))

(ert-deftest imenu-parsing-supports-generic-parameters ()
  (let* ((find-file-hook nil) ;; avoid vc-mode file-hooks when opening!
         (buffer         (find-file-read-only "./test-files/imenu-generics-test.cs"))
         (imenu-index    (csharp--imenu-create-index-helper nil "" t t)) ;; same line as in `csharp-imenu-create-index'.
         (class-entry    (cadr imenu-index))
         (class-entries  (cdr class-entry))
         (imenu-items    (mapconcat 'car class-entries " ")))

    ;; ("(top)" "method void NoGeneric(this IAppBuilder, params object[])" "method void OneGeneric<T>(this IAppBuilder, params object[])" "method void TwoGeneric<T1,T2>(this IAppBuilder, params object[])" "(bottom)")
    (should (string-match-p "NoGeneric" imenu-items))
    (should (string-match-p "OneGeneric<T>" imenu-items))
    (should (string-match-p "TwoGeneric<T1,T2>" imenu-items))
    (kill-buffer buffer)))

(ert-deftest imenu-parsing-supports-comments ()
  (let* ((find-file-hook nil) ;; avoid vc-mode file-hooks when opening!
         (buffer         (find-file-read-only "./test-files/imenu-comment-test.cs"))
         (imenu-index    (csharp--imenu-create-index-helper nil "" t t)) ;; same line as in `csharp-imenu-create-index'.
         (class-entry    (cadr imenu-index))
         (class-entries  (cdr class-entry))
         (imenu-items    (mapconcat 'car class-entries " ")))

    ;; ("(top)" "method void NoGeneric(this IAppBuilder, params object[])" "method void OneGeneric<T>(this IAppBuilder, params object[])" "method void TwoGeneric<T1,T2>(this IAppBuilder, params object[])" "(bottom)")
    (should (string-match-p "HasNoComment" imenu-items))
    (should (string-match-p "HasComment" imenu-items))
    (should (string-match-p "HasCommentToo" imenu-items))
    (kill-buffer buffer)))

(ert-deftest imenu-parsing-supports-explicit-interface-properties ()
  (let* ((find-file-hook nil) ;; avoid vc-mode file-hooks when opening!
         (buffer         (find-file-read-only "./test-files/imenu-interface-property-test.cs"))
         (imenu-index    (csharp--imenu-create-index-helper nil "" t t)) ;; same line as in `csharp-imenu-create-index'.
         (class-entry    (cl-caddr imenu-index))
         (class-entries  (cdr class-entry))
         (imenu-items    (mapconcat 'car class-entries " ")))
    (should (string-match-p "prop IImenuTest.InterfaceString" imenu-items))
    (kill-buffer buffer)))

(ert-deftest imenu-parsing-supports-namespace ()
  (let* ((find-file-hook nil) ;; avoid vc-mode file-hooks when opening!
         (buffer         (find-file-read-only "./test-files/imenu-namespace-test.cs"))
         (imenu-index    (csharp--imenu-create-index-helper nil "" t t)) ;; same line as in `csharp-imenu-create-index'.
         (ns-entry       (cadr imenu-index))
         (ns-item        (car ns-entry)))
    (should (string-match-p "namespace ImenuTest" ns-item))
    (kill-buffer buffer)))

(defvar csharp-hook1 nil)
(defvar csharp-hook2 nil)

(ert-deftest activating-mode-triggers-all-hooks ()
  (add-hook 'csharp-mode-hook (lambda () (setq csharp-hook1 t)))
  (add-hook 'prog-mode-hook   (lambda () (setq csharp-hook2 t)))

  (with-temp-buffer
    (csharp-mode)
    (should (equal t (and csharp-hook1
                          csharp-hook2)))))

(defvar c-mode-hook-run nil)
(ert-deftest avoid-runing-c-mode-hook ()
  (add-hook 'c-mode-hook (lambda () (setq c-mode-hook-run t)))

  (with-temp-buffer
    (csharp-mode)
     (should-not c-mode-hook-run)))

(ert-deftest indentation-rules-should-be-as-specified-in-test-doc ()
  (let* ((buffer (find-file "test-files/indentation-tests.cs"))
         (orig-content)
         (indented-content))
    ;; double-ensure mode is active
    (csharp-mode)

    (setq orig-content (buffer-substring-no-properties (point-min) (point-max)))
    (indent-region (point-min) (point-max))
    (setq indented-content (buffer-substring-no-properties (point-min) (point-max)))

    (should (equal orig-content indented-content))))

;;(ert-run-tests-interactively t)
