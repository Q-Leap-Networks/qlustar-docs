#!/usr/bin/env python3

# Modules included from standard python
import argparse
import os
import re
import sys
import tempfile
from configparser import ConfigParser, ExtendedInterpolation
from lxml import etree

# Modules included from add-on packages
from bs4 import BeautifulSoup # BeautifulSoup

# Local imports

def html_add_colorbox_header(soup):
    colorbox_js = "jquery.colorbox-min.js"
    re_colorbox_js = re.compile(colorbox_js)
    re_jquery_js = re.compile("jquery.*\.js")

    if not soup.find(src=re_colorbox_js):
        orig_tag = soup.find(src=re_jquery_js)
        colorbox_js_tag = soup.new_tag("script")
        colorbox_js_tag['src'] = re.sub(re_jquery_js, colorbox_js, orig_tag['src'])
        colorbox_js_tag['type'] = orig_tag['type']
        colorbox_script_tag = soup.new_tag("script")
        colorbox_script_tag['type'] = orig_tag['type']
        colorbox_script_tag.string =("jQuery(document).ready(function () {"
                                     "  $('a.colorbox').colorbox({"
                                     "    opacity: 0.1,"
                                     "    fixed: true,"
                                     "    maxWidth: '85%',"
                                     "    maxHeight: '85%',"
                                     "    transition: 'elastic',"
                                     "    onLoad: function() {"
                                     "      $.colorbox.resize({ width: $('.cboxPhoto').width() })"
                                     "    }"
                                     "  });"
                                     "});")
        orig_tag.insert_after(colorbox_script_tag)
        orig_tag.insert_after(colorbox_js_tag)

def html_convert_img_to_colorbox(soup):
    for ctag in soup.select(".caption"):
        img_path = ctag.find_previous_sibling("img")['src']
        thumbnail_path = re.sub("images", "images/thumbnails", img_path)
        caption = ctag.find_next("div").string.strip()
        new_div_tag = soup.new_tag("div")
        new_div_tag['class'] = "colorbox"
        new_a_tag = soup.new_tag("a")
        new_a_tag['class'] = "colorbox"
        new_a_tag['href'] = img_path
        new_a_tag['title'] = caption
        new_div_tag.append(new_a_tag)
        new_img_tag = soup.new_tag("img")
        new_img_tag['src'] = thumbnail_path
        new_a_tag.append(new_img_tag)
        ctag.parent.replace_with(new_div_tag)

def html_rearrange_colorboxes(soup):
    for cbtag in soup.select('div[class="colorbox"]'):
        # Wrap all colorboxes that follow each other directly into a div
        prev = cbtag.find_previous_sibling()
        if prev and prev.name == "div":
            try:
                if 'colorbox' in prev['class']:
                    # Remove cbox from current position and reinsert at end of previous paragraph
                    prev.append(cbtag.a)
                    cbtag.extract()
            except KeyError:
                pass

def process_html(soup):
    html_add_colorbox_header(soup)
    html_convert_img_to_colorbox(soup)
    html_rearrange_colorboxes(soup)

def xml_create_cbox_repl_str(matchobj):
    template = ('<mediaobject>\n'
                '  <imageobject><imagedata\n'
                '  fileref="images/{0}"\n'
                '  width="85%" format="PNG"/></imageobject>\n'
                '  <textobject><phrase>\n'
                '    {1}\n'
                '  </phrase></textobject>\n'
                '  <caption><para>\n'
                '    {1}\n'
                '  </para></caption>\n'
                '</mediaobject>').format(matchobj.group("fname"), matchobj.group("caption"))
    repl_str = r""
    for line in template.split('\n'):
        repl_str += matchobj.group("indent") + line
    if matchobj.group("caption"): # Only replace if a caption was supplied
        return repl_str
    else:
        return matchobj.string[matchobj.start():matchobj.end()] # return full match -> no change

def xml_repl_cbox(content):
    re_cbox = re.compile(r"(?P<indent>\s*)<!--cbox\(file: (?P<fname>.*png)\s+caption: (?P<caption>.*?)\)-->")
    return re.sub(re_cbox, xml_create_cbox_repl_str, content)

def process_xml(input_file):
    new_content = xml_repl_cbox(input_file.read())
    return bytes(str(new_content), "UTF-8")

def main():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                     description="Convert Qlustar Doc HTML/XML files",
                                     epilog="XML comments representing an image must be of the form:\n\n"
                                     "  <!--cbox(file: messages/add.png caption: Adding a message filter)-->)\n\n"
                                     "  The path following 'file: ' is relative to the images dir of the project.\n"
                                     "  The text after 'caption: ' will be inserted as the figure caption.")
    parser.add_argument("-i", "--input_file", help = "File to be converted", required=True)
    args = parser.parse_args()
    html = True

    # First check whether input file can be opened and whether XML or HTML
    try:
        with open(args.input_file, encoding="UTF-8") as input_file:
            try:
                tree = etree.parse(input_file)
            except:
                print("Could not parse {0}. Exiting ...".format(args.input_file))
                sys.exit(1)
            if not re.search('DOCTYPE html', tree.docinfo.doctype):
                html = False
    except EnvironmentError as err:
        print(err)
        sys.exit(1)

    # Now reopen file and process
    with open(args.input_file, encoding="UTF-8") as input_file:
        if html:
            soup = BeautifulSoup(input_file)
        else:
            # For XML, we edit a copy of the file and replace the original with the copy at the end
            with tempfile.NamedTemporaryFile(dir=os.path.dirname(args.input_file), delete=False) as out_file:
                out_file.write(process_xml(input_file))
    
    if html:
        process_html(soup)
        try:
            with open(args.input_file, "wb") as out_file:
                out_file.write(bytes(str(soup), "UTF-8"))
        except EnvironmentError as err:
            print(err)
            sys.exit(1)
        file_type = "HTML"
        show_file = re.sub(r".*html-single/", r"", args.input_file)
    else:
        os.replace(out_file.name, args.input_file)
        file_type = "XML"
        show_file = re.sub(r"products/(?P<prod>.*)/(?P<doc>.*)/en-US/(?P<file>.*)",
                           r"\g<prod>|\g<doc>|\g<file>", args.input_file)

    print("Processed {0} file: {1}".format(file_type, show_file))

if __name__ == "__main__":
    main()
    sys.exit(0)
