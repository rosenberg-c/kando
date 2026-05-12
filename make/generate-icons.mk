generate-macos-iconset:
	export_image --source ./art/svg/icon.svg --layer-name "main-1" --target ./art/export/main.png
	generate_iconset --source ./art/export/main.png --target ./apps/apple/Sources/Todo/TodoMacOS/Assets.xcassets --name AppIcon.appiconset

generate-web-iconset:
	@mkdir -p $(WEB_PUBLIC_DIR)
	cp ./art/svg/icon.svg $(WEB_FAVICON_SVG)

iconset: generate-macos-iconset generate-web-iconset
