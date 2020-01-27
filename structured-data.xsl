<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE xsl:stylesheet [
        <!ENTITY amp   "&#38;">
        <!ENTITY copy   "&#169;">
        <!ENTITY gt   "&#62;">
        <!ENTITY hellip "&#8230;">
        <!ENTITY laquo  "&#171;">
        <!ENTITY lsaquo   "&#8249;">
        <!ENTITY lsquo   "&#8216;">
        <!ENTITY lt   "&#60;">
        <!ENTITY nbsp   "&#160;">
        <!ENTITY quot   "&#34;">
        <!ENTITY raquo  "&#187;">
        <!ENTITY rsaquo   "&#8250;">
        <!ENTITY rsquo   "&#8217;">
        ]>
<!--
Structured Data JSON-LD output
-->

<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ouc="http://omniupdate.com/XSL/Variables"
                xmlns:ou="http://omniupdate.com/XSL/Variables"
                xmlns:fn="http://www.w3.org/2005/xpath-functions"
                exclude-result-prefixes="xs ou fn ouc">

    <!-- Function to help with the output of the XML structure for JSON conversion -->
    <xsl:function name="ou:create-string-key">
        <xsl:param name="key" />
        <xsl:param name="value" />
        <fn:string key="{$key}"><xsl:value-of select="$value" /></fn:string>
    </xsl:function>

    <!-- Function to help output the XML for JSON conversion with conditional -->
    <xsl:function name="ou:create-string-key">
        <xsl:param name="key" />
        <xsl:param name="value" />
        <xsl:param name="default-value" />
        <xsl:param name="condition" />
        <fn:string key="{$key}"><xsl:value-of select="if ($condition = 'true') then $value else $default-value" /></fn:string>
    </xsl:function>


    <!-- Global variable for inheriting path to structured data setup file. Can be applied to a site or a folder or written into the PCFs -->
    <xsl:param name="ou:inheritSdPath" select="/_structured-data.inc"/>
    <xsl:variable name="sdPath" select="ou:assignVariable('sdPath', $ou:inheritSdPath)" />

    <!-- Contains the nodes from the structured data setup file -->
    <xsl:variable name="sdNodes">
        <xsl:copy-of select="doc($root || $sdPath)" />
    </xsl:variable>

    <!-- Contains the nodes from the component for structured data -->
    <xsl:variable name="componentNodes">
        <xsl:if test="//component/structured-data">
            <xsl:copy-of select="//component/structured-data/*" />
        </xsl:if>
    </xsl:variable>

    <!-- Contains the PCF tags in readable CSV format-->
    <xsl:variable name="pageTags">
        <xsl:variable name="api-tags" select="ou:get-combined-tags()" />

        <xsl:for-each select="$api-tags/tag">
            <xsl:if test="position() = 1">
                <xsl:value-of select="./name"/>
            </xsl:if>
            <xsl:if test="position() gt 1">
                <xsl:text>, </xsl:text><xsl:value-of select="./name"/>
            </xsl:if>
        </xsl:for-each>
    </xsl:variable>

    <!-- Contains the PCF nodes relevant to schema. There is only an if condition around <author> because it is a nested node. -->
    <xsl:variable name="pageNodes">
        <headline><xsl:value-of select="data/document/ouc:properties[@label='metadata']/title/text()" /></headline>
        <description><xsl:value-of select="data/document/ouc:properties[@label='metadata']/meta[@name='Description']/@content" /></description>
        <xsl:if test="data/document/ouc:properties[@label='metadata']/meta[@name='Author']/@content != ''">
            <author>
                <name>
                    <xsl:value-of select="data/document/ouc:properties[@label='metadata']/meta[@name='Author']/@content" />
                </name>
            </author>
        </xsl:if>
        <datePublished><xsl:value-of select="$ou:created" /></datePublished>
        <dateModified><xsl:value-of select="$ou:modified" /></dateModified>
        <keywords><xsl:copy-of select="$pageTags" /></keywords>
    </xsl:variable>

    <!-- Gross hacky way of getting exact string match using contains. Make sure when adding to this list to put a ',' after the new value.  DO NOT delete the extra space off the front of 'isPartOf' - it will fail to match in template with mode='node-scrubber' -->
    <xsl:variable name="strWhiteListofParentNodeNames" select="' isPartOf, author, about, mainEntityOfPage, publisher, headline, description, datePublished, dateModified, keywords, logo, person,'" />

    <!-- Contains structured data default publisher settings. Includes the University Name, Logo/Image Reference, Logo/Image Height and Logo/Image Width -->
    <xsl:variable name="defaultSettings">
        <isPartOf>
            <name>Name of Your University</name>
            <image>
                <path>Image page of your University Logo</path>
                <height>1200</height>
                <width>800</width>
            </image>
            <url>Url to your University Homepage</url>
        </isPartOf>
    </xsl:variable>

    <!-- Contains all of the node sets in one variable -->
    <xsl:variable name="oneNodeSetToRuleThemAll">
        <xsl:copy-of select="$pageNodes" />
        <xsl:copy-of select="$defaultSettings"/>
        <xsl:copy-of select="$sdNodes//structured-data/*" />
        <xsl:copy-of select="$componentNodes" />
    </xsl:variable>

    <!-- Contains all nodes after they are scrubbed by mode='node-scrubber' -->
    <xsl:variable name="sdNodesScrubbed">
        <xsl:apply-templates select="$oneNodeSetToRuleThemAll/*" mode="node-scrubber"/>
    </xsl:variable>



    <!-- Master template. Converts XML data into json and outputs on the page as a script tag.  -->
    <xsl:template name="structured-data">

        <xsl:text>&#xa;</xsl:text>
        <script type="application/ld+json">

            <!-- Create variable of properly formed XML structure to convert to JSON -->
            <xsl:variable name="xml-for-json">
                <map xmlns="http://www.w3.org/2005/xpath-functions">
                    <xsl:call-template name="mainEntityOfPage" />
                    <xsl:apply-templates select="$sdNodesScrubbed/*" mode="structured-data-parent" />
                </map>
            </xsl:variable>

            <!-- Convert XML structure to JSON -->
            <xsl:value-of select="xml-to-json($xml-for-json)" />

        </script>
        <xsl:text>&#xa;</xsl:text>

    </xsl:template>



    <!--Strips out duplicate parent nodes - Order of precendence: Page Properties, Default Settings, _structured-data.inc, Component -->
    <xsl:template match="*" mode="node-scrubber">

        <xsl:if test="$strWhiteListofParentNodeNames => contains(' ' || name() || ',')">
            <xsl:if test="self::*[not(preceding-sibling::*[name()=(name(current()))]) and (.!='')]">
                <xsl:copy-of select="." />
            </xsl:if>
        </xsl:if>

    </xsl:template>



    <!-- Appends https://$sitePath to the front of dependency tag url references -->
    <xsl:template match="." mode="path-scrubber">
        <xsl:choose>
            <xsl:when test="./text() => contains('http')">
                <xsl:apply-templates select="." mode="structured-data-element" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="scrubbedURL" select="$domain || ./text()"/>
                <xsl:copy-of select="ou:create-string-key(./name(), $scrubbedURL)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>



    <!-- Uses function create-string-key to set node for json processing -->
    <xsl:template match="." mode="structured-data-element">
        <xsl:copy-of select="ou:create-string-key(./name(), ./text())"/>
    </xsl:template>



    <!-- If node has a child, loops again, otherwise sends node to mode='structured-data-element' for processing -->
    <xsl:template match="." mode="structured-data-parent">

        <xsl:choose>
            <xsl:when test="(./name() = 'path') or (./name() = 'url')">
                <xsl:apply-templates select="." mode="path-scrubber" />
            </xsl:when>
            <xsl:when test="not(./*)">
                <xsl:apply-templates select="." mode="structured-data-element" />
            </xsl:when>
            <xsl:otherwise>
                <fn:map key="{./name()}">
                    <xsl:apply-templates select="./*" mode="structured-data-parent"/>
                </fn:map>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>



    <!-- Sets nodes for mainEntityOfPage schema block -->
    <xsl:template name="mainEntityOfPage">
        <fn:map key="mainEntityOfPage">
            <xsl:copy-of select="ou:create-string-key('@type', 'WebPage')" />
            <xsl:copy-of select="ou:create-string-key('@id', $domain || $ou:path)" />
        </fn:map>
    </xsl:template>

</xsl:stylesheet>

