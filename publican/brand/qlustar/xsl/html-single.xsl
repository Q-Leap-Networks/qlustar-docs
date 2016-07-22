<?xml version='1.0'?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml"
    xmlns:d="http://docbook.org/ns/docbook"
    xmlns:exsl="http://exslt.org/common"
    version="1.0"
    exclude-result-prefixes="exsl d"
>

<xsl:import href="http://docbook.sourceforge.net/release/xsl-ns/current/xhtml5/docbook.xsl"/>
<xsl:import href="http://docbook.sourceforge.net/release/xsl-ns/current/xhtml5/chunk.xsl"/>
<xsl:import href="/usr/share/publican/xsl/html-single.xsl"/>

<xsl:param name="generate.toc">
set toc
book toc
article toc
chapter nop
qandadiv toc
qandaset toc
sect1 nop
sect2 nop
sect3 nop
sect4 nop
sect5 nop
section nop
part toc
</xsl:param>

</xsl:stylesheet>

