#!/usr/bin/env python3

# Modules included from standard python
import argparse
import copy
import os
import re
import sys
from configparser import ConfigParser, ExtendedInterpolation

# Modules included from add-on packages
from bs4 import BeautifulSoup # BeautifulSoup

# Local imports

def add_colorbox_header(soup):
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
                                     "$('a.colorbox').colorbox({opacity: 0.1, fixed: true});"
                                     "});")
        orig_tag.insert_after(colorbox_script_tag)
        orig_tag.insert_after(colorbox_js_tag)

def convert_img_to_colorbox(soup):
    for ctag in soup.select(".caption"):
        img_path = ctag.find_previous_sibling("img")['src']
        thumbnail_path = re.sub("images", "images/thumbnails", img_path)
        caption = ctag.find_next("div").string.strip()
        new_a_tag = soup.new_tag("a")
        new_a_tag['class'] = "colorbox"
        new_a_tag['href'] = img_path
        new_a_tag['title'] = caption
        new_img_tag = soup.new_tag("img")
        new_img_tag['src'] = thumbnail_path
        new_a_tag.append(new_img_tag)
        ctag.parent.parent.replace_with(new_a_tag)

def process(soup):
    add_colorbox_header(soup)
    convert_img_to_colorbox(soup)

def main():
    parser = argparse.ArgumentParser(description='Convert Qlustar Doc HTML/XML files')
    parser.add_argument("-i", "--input_file", help = "File to be converted", required=True)
    args = parser.parse_args()

    try:
        with open(args.input_file, encoding="UTF-8") as input_file:
            #data = input_file.read(encoding="utf8")
            soup = BeautifulSoup(input_file)
    except EnvironmentError as err:
        print(err)
        sys.exit(1)
    
    process(soup)

    try:
        with open(args.input_file, "wb") as out_file:
            out_file.write(bytes(str(soup), "UTF-8"))
    except EnvironmentError as err:
        print(err)
        sys.exit(1)

if __name__ == "__main__":
    main()
    sys.exit(0)
