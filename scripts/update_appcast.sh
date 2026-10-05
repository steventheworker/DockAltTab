#!/usr/bin/env bash

set -exu

version="$(cat "$VERSION_FILE")"
date="$(date +'%a, %d %b %Y %H:%M:%S %z')"
minimumSystemVersion="$(awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ { print $2; }' < config/base.xcconfig)"
zipName="$APP_NAME-$version.zip"

escaped_sparkle_key0="$SPARKLE_ED_PRIVATE_KEY"
escaped_sparkle_key1="$escaped_sparkle_key0"
escaped_sparkle_key="${escaped_sparkle_key1/\$HOME/$HOME}"
key_contents=$(cat "$escaped_sparkle_key")
# Use sed to extract the key contents
key_contents=$(echo "$key_contents" | sed -n '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/p')

# Remove the BEGIN and END lines
key_contents=$(echo "$key_contents" | sed '/-----BEGIN PRIVATE KEY-----/d; /-----END PRIVATE KEY-----/d')

# Remove newline characters using tr
key_contents=$(echo -n "$key_contents" | tr -d '\n')

edSignatureAndLength=$(Pods/Sparkle/bin/sign_update -s "$key_contents" "$XCODE_BUILD_PATH/$zipName")

echo "
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:minimumSystemVersion>$minimumSystemVersion</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://dockalttab.netlify.app/changelog-sparkle</sparkle:releaseNotesLink>
      <enclosure
        url=\"https://github.com/steventheworker/alt-tab-macos/releases/download/v$version/$zipName\"
        sparkle:version=\"$version\"
        sparkle:shortVersionString=\"$version\"
        $edSignatureAndLength
        type=\"application/octet-stream\"/>
    </item>
" > ITEM.txt

sed -i '' -e "/<\/language>/r ITEM.txt" appcast.xml
