xib2pdflabels is a simple command-line tool for OS X that generates a multipage PDF from its .xib and .nib inputs, one PDF page per rendered `JRPDFLabel` view.

It supports the [JRPDFLabel](https://github.com/rentzsch/JRPDFLabel) project.

Usage
=====

	xib2pdflabels output.pdf MainMenu.nib MyWindow.xib

Usually you'll want to name the output file JRPDFLabel.pdf and create a Run Script Build Phase in Xcode to automate the generation of your PDF labels from your xibs and nibs.

TODO
====

- Nothing currently planned.

Version History
===============

v1.0.0 (Sat Feb 22 2014)
------------------------
- Initial release.
