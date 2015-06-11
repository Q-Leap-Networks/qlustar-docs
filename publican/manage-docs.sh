#!/bin/bash /usr/lib/qlustar/libexec/run-ql-script.sh

########################################################################
#
# manage-docs.sh
#
# Copyright (C) 2015 Q-Leap Networks
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
#    USA
#
########################################################################

# import qlustar bash modules
import process-args.sh
import status.sh

color=BlueBold

# Stop on errors
set -e

VERSION=%version%
VERBOSITY=0
SCRIPTNAME="${0##*/}"

# Global Qlustar publican defs
QL_LANG=en-US
QL_DTDVER=5.0
QL_WEB_STYLE=2
QL_WEBSITE_TITLE="Qlustar Docs"
QL_BRAND=qlustar
QL_BRAND_DIR="${PWD}/brand/${QL_BRAND}"

# Portal stuff
QL_PORTAL_NAME="Qlustar_Docs_Home"
QL_PORTAL_DIR="${PWD}/${QL_PORTAL_NAME}"

# Product stuff
QL_PRODUCT_DIR="${PWD}/products"

# Website defs
WEB_DIR=website
WEB_DIR_PATH="${PWD}/${WEB_DIR}"
WEB_CFG=qlustar-docs
WEB_CFG_PATH="${WEB_DIR_PATH}/${WEB_CFG}.cfg"
WEB_TOC_PATH="${WEB_DIR_PATH}/html"

# Defs for dev site
QL_DEV_HOST=ql-web-ud
QL_DEV_PATH=/var/www/qlustar-docs
QL_DEV_SITE="http://docs-dev.qlustar.com"

# Publican settings
publican_brand_path=/usr/share/publican/Common_Content/common

# default values
COLOR_OPT=""
WEB_SITE_TYPE=DEV
ALLOWED_ACTIONS=$(concat_string "create-document,update-document,"\
  "create-portal,update-portal," \
  "create-product,update-site,create-website,update-website,")
ALLOWED_ACTIONS=${ALLOWED_ACTIONS// /}

USAGE="Usage: ${SCRIPTNAME} [ options ... ]

    where options include:

     -a, --action <One of create-website,
                          update-website,
                          create-portal,
                          update-portal,
                          create-product,
                          update-site
                          (always required)>
     -s, --site  <Website to create, one of
                          DEV,
                          PROD
                          (optional. Default: $WEB_SITE_TYPE)>
     -h, --help
     -V, --version
     -v, --verbose
"
all_args="-a --action -v --verbose  --no-color -s --site"
while [ $# -gt 0 ]; do
  case "$1" in
    -a|--action)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=$ALLOWED_ACTIONS"
      ACTION="$2"
      shift
      ;;
    --no-color)
      COLOR_OPT="--no-color"; color=""
      ;;
    -p|--product)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=DEV,PROD"
      WEB_SITE_TYPE="$2"
      shift
      ;;
    -s|--site)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=DEV,PROD"
      WEB_SITE_TYPE="$2"
      shift
      ;;
    -v|--verbose)
      VERBOSITY=$((++VERBOSITY))
      ;;
    *) process_common_args "$1" "$USAGE" "$VERSION"
  esac
  shift
done

case $VERBOSITY in
  0)
    CDEB_VERBOSITY="-q"
    ;;
  1)
    CDEB_VERBOSITY=""
    ;;
  2)
    CDEB_VERBOSITY="-v"
    ;;
  *)
    set -x
    CDEB_VERBOSITY="-v --debug"
    ;;
esac

publican_version=$(publican -V)
[[ $publican_version =~ v4.[3] ]] || exit_with_msg $COLOR_OPT \
  -m "Unsupported publican version: $publican_version" -e $ERR_GENERIC

create_and_backup_dir() {
  local dir="$1" nocreate="$2"
  local max_bak=5 bak old_dir dir_bak=${dir}.bak

  [ -d ${dir_bak}$max_bak ] && rm -rf ${dir_bak}$max_bak

  for bak in $(eval echo {$max_bak..2}); do
    old_dir=${dir_bak}$(( $bak - 1 ))
    new_dir=${dir_bak}$bak
    [ -d $old_dir ] && mv $old_dir $new_dir
  done
  [ -d $dir ] && mv $dir ${dir_bak}1
  [ "$nocreate" = "no-create" ] || mkdir $dir
}

publish_brand() {
  tmp_brand_dir="$1" destdir="$2" old_pwd="$PWD"
  
  cd "$tmp_brand_dir"
  publican build --formats=xml --langs=$QL_LANG --publish
  publican install_brand --web --path="${destdir}"
  cd "$old_pwd"
  rm -rf "$tmp_brand_dir"
}

brand_website() {
  local old_pwd="${PWD}" tmp_brand_dir="${PWD}/tmp_brand"

  # Create brand dirs
  mkdir ${WEB_TOC_PATH}/{common,qlustar}

  # First common brand
  [ -d "$tmp_brand_dir" ] && rm -rf "$tmp_brand_dir"
  mkdir "$tmp_brand_dir"
  if [ -d "$publican_brand_path" ]; then
    cp "$publican_brand_path/publican.cfg" "$tmp_brand_dir"
    cp -r "$publican_brand_path/${QL_LANG}" "$tmp_brand_dir"
  else
    exit_with_msg $COLOR_OPT \
      -m "Publican brand not found at $publican_brand_path" -e $ERR_MISSING_FILE
  fi
  publish_brand "$tmp_brand_dir" "${WEB_TOC_PATH}/common"

  # Now Qlustar brand
  rm -rf "$tmp_brand_dir"
  cp -r ../brand/qlustar "$tmp_brand_dir"
  publish_brand "$tmp_brand_dir" "${WEB_TOC_PATH}/qlustar"
  rm -rf "$tmp_brand_dir"
}

create_website() {
  local old_content
  create_and_backup_dir $WEB_DIR
  cd $WEB_DIR
  publican create_site --site_config ${WEB_CFG_PATH} --db_file ${WEB_CFG}.db \
    --toc_path "$WEB_TOC_PATH"
  cat <<-EOF > ${WEB_CFG_PATH} 
	title: "${QL_WEBSITE_TITLE}"
	host: %%%http-site%%%
	def_lang: ${QL_LANG}
	web_style: ${QL_WEB_STYLE}
	manual_toc_update: 1

	$(cat ${WEB_CFG_PATH} | sed -e '/^#/d' -e '/^$/d')
EOF
  touch ${WEB_TOC_PATH}/site_overrides.css
  
  # Add common + Qlustar brand
  brand_website

  # Final update of the site
  publican update_site --site_config ${WEB_CFG}.cfg
}

build_and_publish_document() {
  book_dir="$1"

  cd "$book_dir"
  publican build --publish --formats html-single --brand_dir="$QL_BRAND_DIR" \
    --embedtoc --langs $QL_LANG
  publican install_book --brand_dir="$QL_BRAND_DIR" \
          --site_config ${WEB_CFG_PATH} --lang $QL_LANG
  publican update_site --site_config ${WEB_CFG_PATH}
}

create_portal() {
  local f cfg="${QL_PORTAL_DIR}/publican.cfg"
  local root_file="${QL_PORTAL_DIR}/${QL_LANG}/${QL_PORTAL_NAME}.xml"

  create_and_backup_dir $QL_PORTAL_DIR no-create
  publican create --type Article --name "$QL_PORTAL_NAME" --dtdver $QL_DTDVER \
    --brand $QL_BRAND
  
# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
	web_type: home
EOF

  # Remove unnecessary includes from root xml file
  sed -i -e '/include href/d; /\<index /d' "$root_file"
  sed -i -e \
    's,\(.*<para>\),  <title role="producttitle">%%title%%</title>\n\1,g' \
    "$root_file"
  sed -i -e "s,%%title%%,$QL_WEBSITE_TITLE,g" "$root_file"

  build_and_publish_document "$QL_PORTAL_DIR"
}

create_product() {
  local product="$1"
  local product="Qlustar Cluster OS"
  local product_dir="${QL_PRODUCT_DIR}/${product// /}" name=product_home

  local cfg="${name}/publican.cfg"
  local root_file="${name}/${QL_LANG}/${name}.xml"

  [ -d "product_dir" ] || mkdir -p "$product_dir"
  cd "$product_dir"
  create_and_backup_dir "$name" no-create
  publican create --type Article --name "$name" --dtdver $QL_DTDVER \
    --brand $QL_BRAND --product "$product"
# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
	web_type: product
EOF

  # Remove unnecessary includes from root xml file
  sed -i -e '/include href/d; /\<index /d' "$root_file"

  build_and_publish_document $name
}

create_document() {
  local product="$1" name="$2" version=$3
  local product="Qlustar Cluster OS" name=Admin_Manual version=9.1
  local product_dir="${QL_PRODUCT_DIR}/${product// /}"

  local cfg="${name}/publican.cfg"
  local root_file="${name}/${QL_LANG}/${name}.xml"

  cd "$product_dir"
  create_and_backup_dir "$name" no-create
  publican create --type Article --name "$name" --dtdver $QL_DTDVER \
    --brand $QL_BRAND --version $version --product "$product"

# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
EOF

  build_and_publish_document $name
}

update_site() {
  local site=$WEB_SITE_TYPE
  local site_host_var=QL_${site}_HOST site_path_var=QL_${site}_PATH
  local site_var=QL_${site}_SITE
  local host=${!site_host_var} site_path=${!site_path_var} site_url=${!site_var}
  local tmpdir=update-tmp f

  cd "$WEB_DIR_PATH"
  [ -d $tmpdir ] && rm -rf $tmpdir
  cp -r ${WEB_TOC_PATH} $tmpdir
  find $tmpdir -type f | xargs sed -i -e 's,%%%http-site%%%,'$site_url',g'
  ssh root@${host} "if [ -d $site_path ]; then rm -rf $site_path; fi"
  tar zcf - $tmpdir | ssh root@${host} \
    "cd ${site_path%/*}; tar zxf -; mv $tmpdir $site_path; chown -R root:root $site_path"
  rm -rf $tmpdir
}

case "$ACTION" in
  create-document)    C_PARS=""
    execute=create_document
    msg="Creation of document was successful.";;
  create-portal)     C_PARS=""
    execute=create_portal
    msg="Creation of portal was successful.";;
  update-portal)     C_PARS=""
    execute=update_portal
    msg="Portal update was successful.";;
  create-product)    C_PARS=""
    execute=create_product
    msg="Creation of product was successful.";;
  create-website)    C_PARS=""
    execute=create_website
    msg="Website creation was succesful.";;
  update-site)       C_PARS="WEB_SITE_TYPE"
    execute=update_site
    msg="Update of website was successful.";;
esac

check_args $COLOR_OPT -a "$C_PARS" -s "$SCRIPTNAME" -u "$USAGE"
$execute
print_message $COLOR_OPT "$msg"

exit 0
