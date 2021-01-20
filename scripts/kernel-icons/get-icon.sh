#!/usr/bin/env bash

# download an image and convert it to 64x64 png for use as an ipykernel icon

set -e

[ $# -eq 0 ] && { echo "Usage: $0 image_file_URL"; exit 1; }
imageURL=$1
imageFile=${imageURL##*/}

wget ${imageURL}
convert -size 64x64 ${imageFile} ${imageFile%.*}.png
rm ${imageFile}
