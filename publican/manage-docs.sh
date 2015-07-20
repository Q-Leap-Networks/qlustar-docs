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
VERSION=0.9
VERBOSITY=0
SCRIPTNAME="${0##*/}"

# default values
COLOR_OPT=""
CLEANUP=true
FORMATS=html-single

CFG_FILE="manage-docs.cfg"
. $CFG_FILE 2> /dev/null ||  exit_with_msg $COLOR_OPT \
  -m "Missing config file $CFG_FILE" -e $ERR_MISSING_FILE

# Vars derived from defaults in $CFG_FILE
QL_BRAND_DIR="${PWD}/brand/${QL_BRAND}"
QL_PORTAL_DIR="${PWD}/${QL_PORTAL_NAME}"
WEB_DIR_PATH="${PWD}/${WEB_DIR}"
WEB_CFG_PATH="${WEB_DIR_PATH}/${WEB_CFG}.cfg"
WEB_TOC_PATH="${WEB_DIR_PATH}/html"
# Other global vars
PRODUCT_HOME=product-home
FAVICON="${PWD}/qlustar-favicon.ico"

# cmdline handling
ALLOWED_ACTIONS=$(concat_string "create-document,update-document," \
                                "create-portal,update-portal," \
                                "create-product,update-product," \
                                "create-website,update-website," \
                                "update-site")
ALLOWED_ACTIONS=${ALLOWED_ACTIONS// /} # Remove spaces from concatenation
ALLOWED_ACTIONS_USAGE="$(echo ${ALLOWED_ACTIONS} \
  | sed -e 's/\,/,\n                          /g')"
ALLOWED_FORMATS="html,html-single,pdf,epub,txt"

# Scan for products/documents in product dir
# ------------------------------------------
AVAILABLE_PRODUCTS=""
AVAILABLE_PROD_ALIASES=""
AVAILABLE_PROD_ALIASES_USAGE=""
# AVAILABLE_PRODUCTS array will hold product info
declare -a AVAILABLE_PRODS
AVAILABLE_DOCUMENTS=""
AVAILABLE_DOC_ALIASES=""
AVAILABLE_DOC_ALIASES_USAGE=""
# AVAILABLE_DOCS array will hold document info
declare -a AVAILABLE_DOCS
prod_index=1
doc_index=1
if [ -d "$QL_PRODUCT_DIR" ]; then
  for f1 in $(find "$QL_PRODUCT_DIR" -maxdepth 4 -name ${PRODUCT_HOME}.xml); do

    # First get products
    [[ $f1 =~ bak[1-9] ]] && continue
    prodtitle="$(sed -ne \
      '/title/{s/.*<title role="producttitle">\(.*\)<\/title>.*/\1/p;q;}' $f1)"
    prod_alias="prod-$(printf '%02d' $prod_index)"
    prod_al_u="$prod_alias | $prodtitle"
    AVAILABLE_PRODUCTS="${AVAILABLE_PRODUCTS}${prodtitle},"
    AVAILABLE_PROD_ALIASES="${AVAILABLE_PROD_ALIASES}${prod_alias},"
    AVAILABLE_PROD_ALIASES_USAGE="${AVAILABLE_PROD_ALIASES_USAGE}${prod_al_u},"
    AVAILABLE_PRODS[$prod_index]="${prod_alias},$prodtitle"

    # Now scan for corresponding documents
    for f2 in $(find "${f1%/*/*/*}" -maxdepth 1 -mindepth 1 -type d ); do
      [[ $f2 =~ ${PRODUCT_HOME}|bak ]] && continue
      doc_alias="doc-$(printf '%03d' $doc_index)"
      doc_al_u="$doc_alias | ${f2##*/}\t| $prodtitle"
      AVAILABLE_DOCUMENTS="${AVAILABLE_DOCUMENTS}${f2##*/},"
      AVAILABLE_DOC_ALIASES="${AVAILABLE_DOC_ALIASES}$doc_alias,"
      AVAILABLE_DOC_ALIASES_USAGE="${AVAILABLE_DOC_ALIASES_USAGE}$doc_al_u,"
      # Each entry has 'doc_alias,doc_dir,doc_name,product'
      AVAILABLE_DOCS[$doc_index]="${doc_alias},${f2},${f2##*/},$prodtitle"
      (( ++doc_index ))
    done
    (( ++prod_index ))
  done
fi

# Remove commas at the end
AVAILABLE_PRODUCTS="${AVAILABLE_PRODUCTS%,}"
AVAILABLE_PROD_ALIASES="${AVAILABLE_PROD_ALIASES%,}"
AVAILABLE_PROD_ALIASES_USAGE="${AVAILABLE_PROD_ALIASES_USAGE%,}"
AVAILABLE_DOCUMENTS="${AVAILABLE_DOCUMENTS%,}"
AVAILABLE_DOC_ALIASES="${AVAILABLE_DOC_ALIASES%,}"
AVAILABLE_DOC_ALIASES_USAGE="${AVAILABLE_DOC_ALIASES_USAGE%,}"

USAGE="Usage: ${SCRIPTNAME} [ options ... ]

    where options include:

     -a, --action    <Supported actions:
                            $(echo ${ALLOWED_ACTIONS} \
  | sed -e 's/\,/\n                            /g')
                            (always required)>
     -d, --doc-name  <Name for a new document. Must not have spaces.
                            A space in the name can be achieved by using a '_'.
                            Existing documents:
                            $(echo ${AVAILABLE_DOCUMENTS} \
  | sed -e 's/\,/\n                          /g')
                            (only required for document creation)>
     -D, --doc-id    <Existing document ids:
                            --------+-------------------+---------------------
                               Id   |      Doc Name     |        Product
                            --------+-------------------+---------------------
                            $(echo ${AVAILABLE_DOC_ALIASES_USAGE} \
  | sed -e 's/\,/\n                            /g')
                            (only required for update-document action)>
     --doc-type      <Type of a new document. Must be one of:
                            Article, Book
                            (required for document creation)>
     --doc-version   <Version of a new document:
                            (required for document creation)>
     -f, --formats   <Document formats to create. Must be a comma separated list
                            containing any comination of
                            html, html-single, pdf, epub, txt
                            Default: $FORMATS
                            (only used for update-document)>
     --no-clean      Don't clean publican tmp files after execution
     --no-color      Don't use colored output
     -p, --prod-name <Name for a new product.
                            Existing products:
                            $(echo ${AVAILABLE_PRODUCTS} \
  | sed -e 's/\,/,\n                            /g')
                            (required for product creation)>
     -P, --prod-ids  <Existing product ids:
                            --------+---------------------
                               Id   |        Product
                            --------+---------------------
                            $(echo ${AVAILABLE_PROD_ALIASES_USAGE} \
  | sed -e 's/\,/\n                            /g')
                            (only required for update-product action)>
     -s, --site      <Website to upload content to, one of
                            DEV,
                            PROD
                            (optional. Default: $WEB_SITE_ALIAS)>
     -h, --help
     -v, --verbose
     -V, --version

                           ---------------
                           -- Examples: --
                           ---------------

  - Create a new article document 'Release Notes' for product with id prod-01
    $ ./manage-docs.sh -a create-document -P prod-01 -d 'Release_Notes' \\
      --doc-version 9.1 --doc-type Article

  - Update the article after editing its content (it got the id doc-002)
    $ ./manage-docs.sh -a update-document -D doc-002

  - Create a new product 'Qlustar HPC Stack'
    $ ./manage-docs.sh -a create-product -p 'Qlustar HPC Stack'

  - Update the product page after editing its content (it got the id prod-02)
    $ ./manage-docs.sh -a update-product -P prod-002

  - Recreate website from scratch
    $ ./manage-docs.sh -a create-website
    $ ./manage-docs.sh -a update-portal
    $ ./manage-docs.sh -a update-product -P prod-01 (the same for all other
      prod-??)
    $ ./manage-docs.sh -a update-document -D doc-001  (the same for all other
      doc-??)
"
while [ $# -gt 0 ]; do
  case "$1" in
    -a|--action)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=$ALLOWED_ACTIONS"
      ACTION="$2"
      shift
      ;;
    -d|--doc-name)
      check_single_arg "$all_args" "$USAGE" "$1" "$2"
      DOC_NAME="$2"
      [[ $DOC_NAME = *[[:space:]]* ]] && exit_with_msg $COLOR_OPT \
	-m "Document names must not have spaces!" -e $ERR_USAGE
      shift
      ;;
    -D|--doc-id)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" \
	"allowed=$AVAILABLE_DOC_ALIASES"
      DOC_ID="$2"
      shift
      ;;
    --doc-type)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=Article,Book"
      DOC_TYPE="$2"
      shift
      ;;
    --doc-version)
      check_single_arg "$all_args" "$USAGE" "$1" "$2"
      DOC_VERSION="$2"
      shift
      ;;
    -f|--formats)
      for format in $(echo "${2//,/ }"); do
	check_single_arg "$all_args" "$USAGE" "$1" "$format" \
	  "allowed=$ALLOWED_FORMATS"
      done
      FORMATS="$2"
      shift
      ;;
    --no-clean)
      CLEANUP=false
      ;;
    --no-color)
      COLOR_OPT="--no-color"; color=""
      ;;
    -p|--prod-name)
      check_single_arg "$all_args" "$USAGE" "$1" "$2"
      PROD_NAME="$2"
      shift
      ;;
    -P|--prod-ids)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" \
	"allowed=$AVAILABLE_PROD_ALIASES"
      PROD_ID="$2"
      shift
      ;;
    -s|--site)
      check_single_arg "$all_args" "$USAGE" "$1" "$2" "allowed=DEV,PROD"
      WEB_SITE_ALIAS="$2"
      shift
      ;;
    -v|--verbose)
      VERBOSITY=$((++VERBOSITY))
      ;;
    *) process_common_args "$1" "$USAGE" "$VERSION"
  esac
  shift
done

publican_version=$(publican -V)
[[ $publican_version =~ v4.[3] ]] || exit_with_msg $COLOR_OPT \
  -m "Unsupported publican version: $publican_version" -e $ERR_GENERIC

create_and_backup_dir() {
  local dir="$1" nocreate="$2"
  local max_bak=5 bak old_dir dir_bak="${dir}.bak"

  [ -d "${dir_bak}$max_bak" ] && rm -rf "${dir_bak}$max_bak"

  for bak in $(eval echo {$max_bak..2}); do
    old_dir="${dir_bak}$(( $bak - 1 ))"
    new_dir="${dir_bak}$bak"
    [ -d "$old_dir" ] && mv "$old_dir" "$new_dir"
  done
  [ -d "$dir" ] && mv "$dir" "${dir_bak}1"
  [ "$nocreate" = "no-create" ] || mkdir "$dir"
}

get_prod_name() {
  local prod_id=$1 i field

  for (( i=1 ; n < ${#AVAILABLE_PRODS[@]} ; i++ )); do
    [[ ${AVAILABLE_PRODS[$i]} =~ $prod_id ]] && \
      { field=${AVAILABLE_PRODS[$i]} ; break; }
  done
  echo ${field#*,} # Second field
}

get_doc_dir() {
  local doc_id=$1 i field

  for (( i=1 ; n < ${#AVAILABLE_DOCS[@]} ; i++ )); do
    [[ ${AVAILABLE_DOCS[$i]} =~ $doc_id ]] && \
      { echo ${AVAILABLE_DOCS[$i]} | awk -F ',' '{print $2}'; break; }
  done
}

exec_publican() {
  case $VERBOSITY in
    0) publican "$@" > /dev/null 2>&1;;
    1) publican "$@" > /dev/null;;
    *) publican "$@"
  esac
  [ $? -eq 0 ] || exit_with_msg $COLOR_OPT \
    -m "Publican command: 'publican $@' failed. Start script with -v -v." \
    -e $ERR_GENERIC
}

publish_brand() {
  tmp_brand_dir="$1" destdir="$2" old_pwd="$PWD"
  
  cd "$tmp_brand_dir"
  exec_publican build --formats=xml --langs=$QL_LANG --publish
  exec_publican install_brand --web --path="${destdir}"
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
  exec_publican create_site --site_config ${WEB_CFG_PATH} \
    --db_file ${WEB_CFG}.db --toc_path "$WEB_TOC_PATH"
  cat <<-EOF > ${WEB_CFG_PATH} 
	title: "${QL_WEBSITE_TITLE}"
	host: %%%http-site%%%
	def_lang: ${QL_LANG}
	web_style: ${QL_WEB_STYLE}
	manual_toc_update: 1

	$(cat ${WEB_CFG_PATH} | sed -e '/^#/d' -e '/^$/d')
EOF
  touch ${WEB_TOC_PATH}/site_overrides.css
  # Add favicon
  cp "$FAVICON" ${WEB_TOC_PATH}/favicon.ico
  
  # Add common + Qlustar brand
  brand_website

  # Final update of the site
  exec_publican update_site --site_config ${WEB_CFG}.cfg
}

build_and_publish_document() {
  local book_dir="$1" formats="$2" carousel

  cd "$book_dir"
  exec_publican build --publish --formats "$formats" \
    --brand_dir="$QL_BRAND_DIR" --embedtoc --langs $QL_LANG
  exec_publican install_book --site_config ${WEB_CFG_PATH} --lang $QL_LANG
  exec_publican update_site --site_config ${WEB_CFG_PATH}
  if $CLEANUP; then
    exec_publican clean > /dev/null
  fi
  if [ "$book_dir" = "$QL_PORTAL_DIR" ]; then
    carousel="$book_dir/$QL_LANG/carousel.html"
    [ -e "$carousel" ] && cp -f "$carousel" "$WEB_TOC_PATH"/$QL_LANG
  fi
}

create_portal() {
  local f cfg="${QL_PORTAL_DIR}/publican.cfg"
  local root_file="${QL_PORTAL_DIR}/${QL_LANG}/${QL_PORTAL_NAME}.xml"

  create_and_backup_dir $QL_PORTAL_DIR no-create
  exec_publican create --type Article --name "$QL_PORTAL_NAME" \
    --dtdver $QL_DTDVER --brand $QL_BRAND
  
# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
	web_type: home
EOF

  # Remove unnecessary includes from root xml file
  sed -i -e '/include href/d; /\<index /d' "$root_file"
  # Add title
  sed -i -e \
    's,\(.*<para>\),  <title role="producttitle">%%title%%</title>\n\1,g' \
    "$root_file"
  sed -i -e "s,%%title%%,$QL_WEBSITE_TITLE,g" "$root_file"

  build_and_publish_document "$QL_PORTAL_DIR" html-single
}

create_product() {
  local product="$1"
  local product_dir="${QL_PRODUCT_DIR}/${product// /}" name=$PRODUCT_HOME
  local cfg="${name}/publican.cfg"
  local root_file="${name}/${QL_LANG}/${name}.xml"

  [ -d "product_dir" ] || mkdir -p "$product_dir"
  cd "$product_dir"
  create_and_backup_dir "$name" no-create
  exec_publican create --type Article --name "$name" --dtdver $QL_DTDVER \
    --brand $QL_BRAND --product "$product"
# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
	web_type: product
EOF

  # Remove unnecessary includes from root xml file
  sed -i -e '/include href/d; /\<index /d' "$root_file"
  # Add title
  sed -i -e \
    's,\(.*<para>\),  <title role="producttitle">%%title%%</title>\n\1,g' \
    "$root_file"
  sed -i -e "s,%%title%%,$product,g" "$root_file"

  build_and_publish_document $name html-single
}

create_document() {
  local prod_id="$1" name="$2" version=$3 type=$4
  local product="$(get_prod_name $prod_id)"
  local product_dir="${QL_PRODUCT_DIR}/${product// /}"
  local cfg="${name}/publican.cfg"
  local root_file="${name}/${QL_LANG}/${name}.xml"

  cd "$product_dir"
  create_and_backup_dir "$name" no-create
  exec_publican create --type $type --name "$name" --dtdver $QL_DTDVER \
    --brand $QL_BRAND --version $version --product "$product"

# Cleanup and add web_type: home to cfg
  cat <<-EOF > "$cfg"
	$(cat "$cfg" | sed -e '/^#/d' -e '/^$/d')
EOF

  build_and_publish_document $name html-single
}

update_site() {
  local site=$WEB_SITE_ALIAS
  local site_host_var=QL_${site}_HOST site_path_var=QL_${site}_PATH
  local site_var=QL_${site}_SITE
  local host=${!site_host_var} site_path=${!site_path_var} site_url=${!site_var}
  local tmpdir=update-tmp f

  cd "$WEB_DIR_PATH"
  [ -d $tmpdir ] && rm -rf $tmpdir
  cp -r ${WEB_TOC_PATH} $tmpdir
  find $tmpdir -type f | xargs sed -i -e 's,%%%http-site%%%,'$site_url',g' \
    -e 's,http://www.google.com/search,https://www.google.com/search,g' \
    -e 's/___blank___"/" target="_blank"/g'
  ssh root@${host} "if [ -d $site_path ]; then rm -rf $site_path; fi"
  tar zcf - $tmpdir | ssh root@${host} \
    "cd ${site_path%/*}; tar zxf -; mv $tmpdir $site_path; 
     chown -R root:root $site_path"
  rm -rf $tmpdir
}

declare -a execute_args
case "$ACTION" in
  create-document)    C_PARS="DOC_NAME DOC_VERSION DOC_TYPE PROD_ID"
    execute=create_document
    execute_args[1]=$PROD_ID
    execute_args[2]="$DOC_NAME"
    execute_args[3]=$DOC_VERSION
    execute_args[4]=$DOC_TYPE
    msg="Creation of document $DOC_NAME for prod_id $PROD_ID was successful.";;
  create-portal)     C_PARS=""
    execute=create_portal
    msg="Creation of portal was successful.";;
  create-product)    C_PARS="PROD_NAME"
    execute=create_product
    execute_args[1]="$PROD_NAME"
    execute_args="$PROD_NAME"
    msg="Creation of product $PROD_NAME was successful.";;
  create-website)    C_PARS=""
    execute=create_website
    msg="Website creation was succesful.";;
  update-document)     C_PARS="DOC_ID"
    doc_dir="$(get_doc_dir $DOC_ID)"
    execute=build_and_publish_document
    execute_args[1]="$doc_dir"
    execute_args[2]=$FORMATS
    msg="Update of document ${doc_dir##*/} was successful.";;
  update-portal)     C_PARS=""
    execute=build_and_publish_document
    execute_args[1]="$QL_PORTAL_DIR"
    execute_args[2]="html-single"
    msg="Portal update was successful.";;
  update-product)     C_PARS="PROD_ID"
    prod_name="$(get_prod_name $PROD_ID)"
    prod_dir="${QL_PRODUCT_DIR}/${prod_name// /}/${PRODUCT_HOME}"
    execute=build_and_publish_document
    execute_args[1]="$prod_dir"
    execute_args[2]="html-single"
    msg="Update of product '$prod_name' was successful.";;
  update-site)       C_PARS="WEB_SITE_ALIAS"
    execute=update_site
    msg="Update of website was successful.";;
esac

check_args $COLOR_OPT -a "$C_PARS" -s "$SCRIPTNAME" -u "$USAGE"
$execute "${execute_args[@]}"
    
print_message $COLOR_OPT "$msg"

exit 0
