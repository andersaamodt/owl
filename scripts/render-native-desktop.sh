#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
ir_path="$project_dir/app-blueprint/app.ir.yaml"
schema_path="$project_dir/schemas/native-desktop-ir-v1.json"
generated_root="$project_dir/generated"
macos_dir="$generated_root/macos"
linux_dir="$generated_root/linux"
template_root="$project_dir/templates"
version_file="$project_dir/VERSION"

"$script_dir/validate-native-desktop-ir.sh" "$ir_path" "$schema_path" >/dev/null

app_name=$(jq -r '.app.name' "$ir_path")
app_id=$(jq -r '.app.id' "$ir_path")
window_title=$(jq -r '.app.window.title // .app.name' "$ir_path")
app_menu_title=$(jq -r '([.app.window.menuBar.children[]? | select(.id == "menu.app") | .title][0] // .app.name)' "$ir_path")
if [ -f "$version_file" ]; then
  app_version=$(tr -d ' \t\r\n' <"$version_file")
else
  app_version=0.1.0
fi
pretty_ir=$(jq '.' "$ir_path")
linux_ir_literal=$(printf '%s\n' "$pretty_ir" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/  "/; s/$/\\n"/')

mkdir -p "$macos_dir/Sources/App" "$linux_dir/src"

actions_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-actions.XXXXXX")
swift_cases_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-swift-actions.XXXXXX")
linux_setup_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-linux-actions.XXXXXX")
linux_handlers_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-linux-handlers.XXXXXX")
trap 'rm -f "$actions_tmp" "$swift_cases_tmp" "$linux_setup_tmp" "$linux_handlers_tmp"' EXIT HUP INT TERM

jq -r '.app.actions[].id' "$ir_path" >"$actions_tmp"

while IFS= read -r action_id; do
  [ -n "$action_id" ] || continue
  printf '      case "%s":\n        runSymbolicAction("%s")\n' "$action_id" "$action_id" >>"$swift_cases_tmp"
  linux_action_id=$(printf '%s' "$action_id" | tr '_' '-')
  printf '  add_app_action(app, context, "%s");\n' "$linux_action_id" >>"$linux_setup_tmp"
  case "$linux_action_id" in
    tick-simplex)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_backend_status(context, "Checked SimpleX incoming queue.", "tick-simplex", NULL, NULL); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    install-simplex-cli)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_backend_status(context, "SimpleX CLI install action completed.", "install-simplex-cli", NULL, NULL); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    provision-simplex-identity)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_backend_status(context, "Provisioned SimpleX identity.", "provision-simplex-identity", "default", NULL); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    configure-simplex-local-transport)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_backend_status(context, "Enabled local SimpleX transport.", "configure-simplex-local-transport", "default", NULL); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    quit-app)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { g_application_quit(G_APPLICATION(context->app)); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    compose-email)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_status(context, "Email selected explicitly; open-lock warning treatment applies."); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    compose-simplex)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_status(context, "SimpleX selected as preferred secure transport."); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    send-message)
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_status(context, "Use the native composer transport selector before sending."); return; }\n' "$linux_action_id" >>"$linux_handlers_tmp"
      ;;
    *)
      label=$(printf '%s' "$linux_action_id" | tr '-' ' ')
      printf '  if (g_strcmp0(action_name, "%s") == 0) { set_status(context, "%s"); return; }\n' "$linux_action_id" "$label" >>"$linux_handlers_tmp"
      ;;
  esac
done <"$actions_tmp"

swift_action_cases=$(cat "$swift_cases_tmp")
linux_action_setup=$(cat "$linux_setup_tmp")
linux_action_handlers=$(cat "$linux_handlers_tmp")

render_template_file() {
  template_path=$1
  output_path=$2
  mkdir -p "$(dirname "$output_path")"
  output_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-render.XXXXXX")
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "__CANONICAL_IR__")
        printf '%s\n' "$pretty_ir" >>"$output_tmp"
        ;;
      "__LINUX_IR_LITERAL__")
        printf '%s\n' "$linux_ir_literal" >>"$output_tmp"
        ;;
      "__LINUX_IR_LITERAL__;")
        printf '%s\n' "$linux_ir_literal" >>"$output_tmp"
        printf '%s\n' ";" >>"$output_tmp"
        ;;
      "__SWIFT_ACTION_CASES__")
        printf '%s\n' "$swift_action_cases" >>"$output_tmp"
        ;;
      "__LINUX_ACTION_SETUP__")
        printf '%s\n' "$linux_action_setup" >>"$output_tmp"
        ;;
      "__LINUX_ACTION_HANDLERS__")
        printf '%s\n' "$linux_action_handlers" >>"$output_tmp"
        ;;
      *)
        printf '%s\n' "$line" \
          | sed \
            -e "s/__APP_NAME__/$app_name/g" \
            -e "s/__APP_MENU_TITLE__/$app_menu_title/g" \
            -e "s/__APP_ID__/$app_id/g" \
            -e "s/__APP_VERSION__/$app_version/g" \
            -e "s/__WINDOW_TITLE__/$window_title/g" >>"$output_tmp"
        ;;
    esac
  done <"$template_path"
  mv "$output_tmp" "$output_path"
}

cat >"$macos_dir/Package.swift" <<EOF_PACKAGE
// Generated from app-blueprint/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "$app_id",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "$app_id", targets: ["App"])
  ],
  targets: [
    .executableTarget(
      name: "App",
      path: "Sources/App",
      linkerSettings: [
        .linkedFramework("AVKit")
      ]
    )
  ]
)
EOF_PACKAGE

cat >"$linux_dir/meson.build" <<EOF_MESON
# Generated from app-blueprint/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
project('$app_id', 'c', version: '$app_version')

gtk_dep = dependency('gtk4')

executable(
  '$app_id',
  ['src/main.c'],
  dependencies: [gtk_dep],
  install: false,
)
EOF_MESON

render_template_file "$template_root/macos/App.swift.template" "$macos_dir/Sources/App/App.swift"
render_template_file "$template_root/linux/main.c.template" "$linux_dir/src/main.c"

printf 'status=ok\n'
printf 'ir=%s\n' "$ir_path"
printf 'macos=%s\n' "$macos_dir"
printf 'linux=%s\n' "$linux_dir"
