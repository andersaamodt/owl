/* Generated from app-blueprint/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh. */
#include <gtk/gtk.h>

static const char *wizardry_app_ir =
  "{\n"
  "  \"version\": \"native-desktop-ir/v1\",\n"
  "  \"format\": \"yaml-1.2-json-compatible\",\n"
  "  \"app\": {\n"
  "    \"id\": \"stellar\",\n"
  "    \"name\": \"Stellar\",\n"
  "    \"targets\": [\n"
  "      \"macos\",\n"
  "      \"linux\"\n"
  "    ],\n"
  "    \"actions\": [\n"
  "      {\n"
  "        \"id\": \"focus_new\",\n"
  "        \"title\": \"New Senders\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_inbox\",\n"
  "        \"title\": \"Inbox\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_mail\",\n"
  "        \"title\": \"Mail\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_archive\",\n"
  "        \"title\": \"Archive\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_favorites\",\n"
  "        \"title\": \"Favorites\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_people\",\n"
  "        \"title\": \"People\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"focus_groups\",\n"
  "        \"title\": \"Groups\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"send_message\",\n"
  "        \"title\": \"Send Message\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"archive_message\",\n"
  "        \"title\": \"Remove From Inbox\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"delete_message\",\n"
  "        \"title\": \"Delete\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"toggle_star\",\n"
  "        \"title\": \"Star\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"mark_read\",\n"
  "        \"title\": \"Mark Read\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"open_settings\",\n"
  "        \"title\": \"Settings\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"choose_mail_root\",\n"
  "        \"title\": \"Choose Mail Root\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"install_simplex_cli\",\n"
  "        \"title\": \"Install SimpleX CLI\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"provision_simplex_identity\",\n"
  "        \"title\": \"Provision SimpleX Identity\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"configure_simplex_local_transport\",\n"
  "        \"title\": \"Enable Local SimpleX Transport\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"tick_simplex\",\n"
  "        \"title\": \"Check SimpleX\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"bind_contact\",\n"
  "        \"title\": \"Bind Contact\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"compose_simplex\",\n"
  "        \"title\": \"Use SimpleX\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"compose_email\",\n"
  "        \"title\": \"Use Email\"\n"
  "      },\n"
  "      {\n"
  "        \"id\": \"quit_app\",\n"
  "        \"title\": \"Quit\"\n"
  "      }\n"
  "    ],\n"
  "    \"state\": {\n"
  "      \"mailRoot\": \"~/mail\",\n"
  "      \"selectedRoute\": \"inbox\",\n"
  "      \"selectedTransport\": \"simplex\"\n"
  "    },\n"
  "    \"window\": {\n"
  "      \"id\": \"window.main\",\n"
  "      \"name\": \"mainWindow\",\n"
  "      \"type\": \"Window\",\n"
  "      \"title\": \"Stellar\",\n"
  "      \"width\": 128,\n"
  "      \"minWidth\": 96,\n"
  "      \"height\": 82,\n"
  "      \"minHeight\": 58,\n"
  "      \"menuBar\": {\n"
  "        \"id\": \"menubar.main\",\n"
  "        \"type\": \"MenuBar\",\n"
  "        \"children\": [\n"
  "          {\n"
  "            \"id\": \"menu.app\",\n"
  "            \"type\": \"Menu\",\n"
  "            \"title\": \"Stellar\",\n"
  "            \"children\": [\n"
  "              {\n"
  "                \"id\": \"menuitem.settings\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Settings\",\n"
  "                \"action\": \"open_settings\",\n"
  "                \"shortcut\": \"cmd+,\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.quit\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Quit\",\n"
  "                \"action\": \"quit_app\",\n"
  "                \"shortcut\": \"cmd+q\"\n"
  "              }\n"
  "            ]\n"
  "          },\n"
  "          {\n"
  "            \"id\": \"menu.view\",\n"
  "            \"type\": \"Menu\",\n"
  "            \"title\": \"View\",\n"
  "            \"children\": [\n"
  "              {\n"
  "                \"id\": \"menuitem.inbox\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Inbox\",\n"
  "                \"action\": \"focus_inbox\",\n"
  "                \"shortcut\": \"cmd+1\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.favorites\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Favorites\",\n"
  "                \"action\": \"focus_favorites\",\n"
  "                \"shortcut\": \"cmd+2\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.people\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"People\",\n"
  "                \"action\": \"focus_people\",\n"
  "                \"shortcut\": \"cmd+3\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.groups\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Groups\",\n"
  "                \"action\": \"focus_groups\",\n"
  "                \"shortcut\": \"cmd+4\"\n"
  "              }\n"
  "            ]\n"
  "          },\n"
  "          {\n"
  "            \"id\": \"menu.transport\",\n"
  "            \"type\": \"Menu\",\n"
  "            \"title\": \"Transport\",\n"
  "            \"children\": [\n"
  "              {\n"
  "                \"id\": \"menuitem.simplex\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Compose With SimpleX\",\n"
  "                \"action\": \"compose_simplex\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.email\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Compose With Email\",\n"
  "                \"action\": \"compose_email\"\n"
  "              },\n"
  "              {\n"
  "                \"id\": \"menuitem.tickSimplex\",\n"
  "                \"type\": \"MenuItem\",\n"
  "                \"title\": \"Check SimpleX\",\n"
  "                \"action\": \"tick_simplex\"\n"
  "              }\n"
  "            ]\n"
  "          }\n"
  "        ]\n"
  "      },\n"
  "      \"toolbar\": {\n"
  "        \"id\": \"toolbar.main\",\n"
  "        \"type\": \"Toolbar\",\n"
  "        \"children\": [\n"
  "          {\n"
  "            \"id\": \"toolbar.inbox\",\n"
  "            \"type\": \"Button\",\n"
  "            \"title\": \"Inbox\",\n"
  "            \"action\": \"focus_inbox\"\n"
  "          },\n"
  "          {\n"
  "            \"id\": \"toolbar.spacer\",\n"
  "            \"type\": \"Spacer\"\n"
  "          },\n"
  "          {\n"
  "            \"id\": \"toolbar.simplex\",\n"
  "            \"type\": \"Button\",\n"
  "            \"title\": \"Check SimpleX\",\n"
  "            \"action\": \"tick_simplex\"\n"
  "          },\n"
  "          {\n"
  "            \"id\": \"toolbar.settings\",\n"
  "            \"type\": \"Button\",\n"
  "            \"title\": \"Settings\",\n"
  "            \"action\": \"open_settings\"\n"
  "          }\n"
  "        ]\n"
  "      },\n"
  "      \"content\": {\n"
  "        \"id\": \"content.main\",\n"
  "        \"type\": \"Content\",\n"
  "        \"child\": {\n"
  "          \"id\": \"split.messenger\",\n"
  "          \"type\": \"Split\",\n"
  "          \"children\": [\n"
  "            {\n"
  "              \"id\": \"sidebar.contacts\",\n"
  "              \"type\": \"Sidebar\",\n"
  "              \"children\": [\n"
  "                {\n"
  "                  \"id\": \"list.inbox\",\n"
  "                  \"type\": \"List\",\n"
  "                  \"title\": \"Inbox\",\n"
  "                  \"action\": \"focus_inbox\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"list.favorites\",\n"
  "                  \"type\": \"List\",\n"
  "                  \"title\": \"Favorites\",\n"
  "                  \"action\": \"focus_favorites\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"list.people\",\n"
  "                  \"type\": \"List\",\n"
  "                  \"title\": \"People\",\n"
  "                  \"action\": \"focus_people\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"list.groups\",\n"
  "                  \"type\": \"List\",\n"
  "                  \"title\": \"Groups\",\n"
  "                  \"action\": \"focus_groups\"\n"
  "                }\n"
  "              ]\n"
  "            },\n"
  "            {\n"
  "              \"id\": \"detail.timeline\",\n"
  "              \"type\": \"Detail\",\n"
  "              \"children\": [\n"
  "                {\n"
  "                  \"id\": \"section.timeline\",\n"
  "                  \"type\": \"Section\",\n"
  "                  \"title\": \"Timeline\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"form.compose\",\n"
  "                  \"type\": \"Form\",\n"
  "                  \"title\": \"Compose\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"select.transport\",\n"
  "                  \"type\": \"Select\",\n"
  "                  \"title\": \"Transport\",\n"
  "                  \"action\": \"compose_simplex\"\n"
  "                },\n"
  "                {\n"
  "                  \"id\": \"button.send\",\n"
  "                  \"type\": \"Button\",\n"
  "                  \"title\": \"Send\",\n"
  "                  \"action\": \"send_message\"\n"
  "                }\n"
  "              ]\n"
  "            }\n"
  "          ]\n"
  "        }\n"
  "      }\n"
  "    },\n"
  "    \"mock\": {\n"
  "      \"contacts\": [\n"
  "        {\n"
  "          \"id\": \"alice-ledger\",\n"
  "          \"kind\": \"person\",\n"
  "          \"name\": \"Alice Ledger\",\n"
  "          \"email\": \"alice@example.org\",\n"
  "          \"simplex_address\": \"simplex://alice-ledger\",\n"
  "          \"favorite\": true\n"
  "        },\n"
  "        {\n"
  "          \"id\": \"river-stone\",\n"
  "          \"kind\": \"group\",\n"
  "          \"name\": \"River Stone\",\n"
  "          \"email\": \"\",\n"
  "          \"simplex_address\": \"simplex://river-stone\",\n"
  "          \"favorite\": true\n"
  "        }\n"
  "      ],\n"
  "      \"messages\": [\n"
  "        {\n"
  "          \"id\": \"seed-email-1\",\n"
  "          \"thread_id\": \"alice-ledger\",\n"
  "          \"transport\": \"email\",\n"
  "          \"lock\": \"open\",\n"
  "          \"subject\": \"Longer email-style note\",\n"
  "          \"body\": \"This is a longer email-shaped message rendered in the same continuous contact timeline as short chat messages.\",\n"
  "          \"received_at\": \"2026-04-20T10:00:00Z\",\n"
  "          \"in_inbox\": true,\n"
  "          \"from_self\": false\n"
  "        },\n"
  "        {\n"
  "          \"id\": \"seed-simplex-1\",\n"
  "          \"thread_id\": \"alice-ledger\",\n"
  "          \"transport\": \"simplex\",\n"
  "          \"lock\": \"closed\",\n"
  "          \"subject\": \"\",\n"
  "          \"body\": \"Short secure reply.\",\n"
  "          \"received_at\": \"2026-04-20T10:03:00Z\",\n"
  "          \"in_inbox\": false,\n"
  "          \"from_self\": true\n"
  "        }\n"
  "      ]\n"
  "    }\n"
  "  },\n"
  "  \"extensions\": []\n"
  "}\n"
;

typedef struct {
  GtkApplication *app;
  GtkWidget *window;
  GtkWidget *stack;
  GtkWidget *status_label;
  GtkWidget *inbox_list;
  GtkWidget *mailbox_list;
  GtkWidget *thread_list;
  GtkWidget *composer;
  gchar *mail_root;
} AppContext;

static char *default_mail_root(void) {
  const char *home = g_get_home_dir();
  if (home == NULL || *home == '\0') {
    home = ".";
  }
  return g_build_filename(home, "mail", NULL);
}

static char *resolve_backend_script(void) {
  const char *override = g_getenv("STELLAR_BACKEND");
  if (override != NULL && *override != '\0' && g_file_test(override, G_FILE_TEST_EXISTS)) {
    return g_strdup(override);
  }

  char *cwd = g_get_current_dir();
  char *candidate = g_build_filename(cwd, "../../scripts/stellar-backend.sh", NULL);
  if (g_file_test(candidate, G_FILE_TEST_EXISTS)) {
    g_free(cwd);
    return candidate;
  }
  g_free(candidate);

  candidate = g_build_filename(cwd, "scripts/stellar-backend.sh", NULL);
  if (g_file_test(candidate, G_FILE_TEST_EXISTS)) {
    g_free(cwd);
    return candidate;
  }
  g_free(candidate);
  g_free(cwd);

  char *exe_link = g_file_read_link("/proc/self/exe", NULL);
  if (exe_link != NULL) {
    char *exe_dir = g_path_get_dirname(exe_link);
    candidate = g_build_filename(exe_dir, "../Resources/scripts/stellar-backend.sh", NULL);
    g_free(exe_dir);
    g_free(exe_link);
    if (g_file_test(candidate, G_FILE_TEST_EXISTS)) {
      return candidate;
    }
    g_free(candidate);
  }

  const char *home = g_get_home_dir();
  if (home != NULL) {
    candidate = g_build_filename(home, "git/stellar/scripts/stellar-backend.sh", NULL);
    if (g_file_test(candidate, G_FILE_TEST_EXISTS)) {
      return candidate;
    }
    g_free(candidate);
  }
  return NULL;
}

static char *run_backend(AppContext *context, const char *action, const char *arg1, const char *arg2) {
  char *script_path = resolve_backend_script();
  if (script_path == NULL) {
    return g_strdup("Stellar backend script not found.");
  }

  GPtrArray *argv = g_ptr_array_new();
  g_ptr_array_add(argv, (char *)"/bin/sh");
  g_ptr_array_add(argv, script_path);
  g_ptr_array_add(argv, (char *)action);
  g_ptr_array_add(argv, context->mail_root);
  if (arg1 != NULL) {
    g_ptr_array_add(argv, (char *)arg1);
  }
  if (arg2 != NULL) {
    g_ptr_array_add(argv, (char *)arg2);
  }
  g_ptr_array_add(argv, NULL);

  gchar *stdout_text = NULL;
  gchar *stderr_text = NULL;
  gint status = 0;
  GError *error = NULL;
  gboolean ok = g_spawn_sync(NULL, (gchar **)argv->pdata, NULL, G_SPAWN_DEFAULT, NULL, NULL, &stdout_text, &stderr_text, &status, &error);
  g_ptr_array_free(argv, TRUE);
  g_free(script_path);

  if (!ok) {
    char *message = g_strdup(error != NULL ? error->message : "backend spawn failed");
    if (error != NULL) {
      g_error_free(error);
    }
    g_free(stdout_text);
    g_free(stderr_text);
    return message;
  }
  if (status != 0) {
    char *message = g_strdup((stderr_text != NULL && *stderr_text != '\0') ? stderr_text : "backend command failed");
    g_free(stdout_text);
    g_free(stderr_text);
    return message;
  }
  char *message = g_strdup((stdout_text != NULL && *stdout_text != '\0') ? stdout_text : "ok");
  g_free(stdout_text);
  g_free(stderr_text);
  return message;
}

static void set_status(AppContext *context, const char *message) {
  gtk_label_set_text(GTK_LABEL(context->status_label), message);
}

static void set_backend_status(AppContext *context, const char *success_message, const char *action, const char *arg1, const char *arg2) {
  char *output = run_backend(context, action, arg1, arg2);
  if (output != NULL && *output != '\0') {
    set_status(context, success_message);
  } else {
    set_status(context, output != NULL ? output : "Backend returned no output.");
  }
  g_free(output);
}

static void clear_list_box(GtkWidget *list) {
  GtkWidget *child = gtk_widget_get_first_child(list);
  while (child != NULL) {
    GtkWidget *next = gtk_widget_get_next_sibling(child);
    gtk_list_box_remove(GTK_LIST_BOX(list), child);
    child = next;
  }
}

static GtkWidget *make_badge(const char *text) {
  GtkWidget *label = gtk_label_new(text);
  gtk_widget_add_css_class(label, "badge");
  return label;
}

static GtkWidget *make_transport_mark(const char *transport) {
  const gboolean simplex = g_strcmp0(transport, "simplex") == 0;
  GtkWidget *label = gtk_label_new(simplex ? "closed lock  SimpleX" : "open lock  Email");
  gtk_widget_add_css_class(label, simplex ? "secure-transport" : "email-transport");
  return label;
}

static const char *safe_field(char **fields, guint length, guint index) {
  if (index >= length || fields[index] == NULL) {
    return "";
  }
  return fields[index];
}

static GtkWidget *make_sidebar_row(const char *title, const char *subtitle, int count) {
  GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  GtkWidget *copy = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
  GtkWidget *title_label = gtk_label_new(title);
  GtkWidget *subtitle_label = gtk_label_new(subtitle);
  gtk_label_set_xalign(GTK_LABEL(title_label), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(subtitle_label), 0.0f);
  gtk_widget_add_css_class(title_label, "sidebar-title");
  gtk_widget_add_css_class(subtitle_label, "sidebar-subtitle");
  gtk_box_append(GTK_BOX(copy), title_label);
  gtk_box_append(GTK_BOX(copy), subtitle_label);
  gtk_box_append(GTK_BOX(row), copy);
  gtk_widget_set_hexpand(copy, TRUE);
  if (count > 0) {
    char *count_text = g_strdup_printf("%d", count);
    gtk_box_append(GTK_BOX(row), make_badge(count_text));
    g_free(count_text);
  }
  return row;
}

static GtkWidget *make_inbox_card(const char *contact, const char *transport, const char *subject, const char *body) {
  GtkWidget *card = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *head = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  GtkWidget *contact_label = gtk_label_new(contact);
  GtkWidget *subject_label = gtk_label_new(subject);
  GtkWidget *body_label = gtk_label_new(body);
  gtk_widget_add_css_class(card, "message-card");
  gtk_label_set_xalign(GTK_LABEL(contact_label), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(subject_label), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(body_label), 0.0f);
  gtk_label_set_wrap(GTK_LABEL(body_label), TRUE);
  gtk_box_append(GTK_BOX(head), make_transport_mark(transport));
  gtk_box_append(GTK_BOX(head), contact_label);
  gtk_box_append(GTK_BOX(card), head);
  if (subject != NULL && *subject != '\0') {
    gtk_widget_add_css_class(subject_label, "subject");
    gtk_box_append(GTK_BOX(card), subject_label);
  }
  gtk_box_append(GTK_BOX(card), body_label);
  return card;
}

static void populate_seed_lists(AppContext *context) {
  clear_list_box(context->inbox_list);
  clear_list_box(context->mailbox_list);
  clear_list_box(context->thread_list);
  gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row("Accepted", "1 message", 1));
  gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row("Archive", "0 messages", 0));
  gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row("Sent", "0 messages", 0));
  gtk_list_box_append(GTK_LIST_BOX(context->inbox_list), make_inbox_card("Alice Ledger", "email", "Longer email-style note", "Unified native inbox item."));
  gtk_list_box_append(GTK_LIST_BOX(context->inbox_list), make_inbox_card("River Stone", "simplex", "", "Group update landed over SimpleX."));
  gtk_list_box_append(GTK_LIST_BOX(context->thread_list), make_sidebar_row("Alice Ledger", "SimpleX + email", 1));
  gtk_list_box_append(GTK_LIST_BOX(context->thread_list), make_sidebar_row("River Stone", "Group - SimpleX", 1));
}

static void populate_snapshot_lines(AppContext *context, const char *output) {
  clear_list_box(context->inbox_list);
  clear_list_box(context->mailbox_list);
  clear_list_box(context->thread_list);

  gboolean added_any = FALSE;
  char **lines = g_strsplit(output, "\n", -1);
  for (guint i = 0; lines[i] != NULL; i++) {
    if (*lines[i] == '\0') {
      continue;
    }
    char **fields = g_strsplit(lines[i], "\t", -1);
    guint length = g_strv_length(fields);
    const char *kind = safe_field(fields, length, 0);
    if (g_strcmp0(kind, "mailbox") == 0) {
      const char *count_text = safe_field(fields, length, 3);
      const char *unread_text = safe_field(fields, length, 4);
      char *subtitle = g_strdup_printf("%s messages", *count_text != '\0' ? count_text : "0");
      gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row(safe_field(fields, length, 2), subtitle, atoi(unread_text)));
      g_free(subtitle);
      added_any = TRUE;
    } else if (g_strcmp0(kind, "inbox") == 0) {
      gtk_list_box_append(
        GTK_LIST_BOX(context->inbox_list),
        make_inbox_card(safe_field(fields, length, 2), safe_field(fields, length, 3), safe_field(fields, length, 4), safe_field(fields, length, 5))
      );
      added_any = TRUE;
    } else if (g_strcmp0(kind, "thread") == 0) {
      const char *thread_kind = safe_field(fields, length, 3);
      const char *unread_text = safe_field(fields, length, 4);
      const char *simplex_path = safe_field(fields, length, 6);
      const char *email_path = safe_field(fields, length, 7);
      char *subtitle = g_strdup_printf(
        "%s%s%s",
        g_strcmp0(thread_kind, "group") == 0 ? "Group" : "Person",
        *simplex_path != '\0' ? " - SimpleX" : "",
        *email_path != '\0' ? " - email" : ""
      );
      gtk_list_box_append(GTK_LIST_BOX(context->thread_list), make_sidebar_row(safe_field(fields, length, 2), subtitle, atoi(unread_text)));
      g_free(subtitle);
      added_any = TRUE;
    } else if (g_strcmp0(kind, "draft") == 0) {
      gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row("Drafts", safe_field(fields, length, 3), 0));
      added_any = TRUE;
    } else if (g_strcmp0(kind, "event") == 0) {
      gtk_list_box_append(GTK_LIST_BOX(context->mailbox_list), make_sidebar_row("Events", safe_field(fields, length, 2), 0));
      added_any = TRUE;
    }
    g_strfreev(fields);
  }
  g_strfreev(lines);

  if (!added_any) {
    gtk_list_box_append(GTK_LIST_BOX(context->inbox_list), make_inbox_card("Stellar", "simplex", "", "Backend snapshot is empty."));
  }
}

static void refresh_from_backend(AppContext *context) {
  char *output = run_backend(context, "snapshot-lines", NULL, NULL);
  if (output != NULL && g_str_has_prefix(output, "root\t")) {
    populate_snapshot_lines(context, output);
    set_status(context, "Loaded Stellar snapshot.");
  } else {
    populate_seed_lists(context);
    set_status(context, output != NULL ? output : "Backend unavailable.");
  }
  g_free(output);
}

static GtkWidget *make_sidebar(AppContext *context) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *search = gtk_search_entry_new();
  GtkWidget *inbox = make_sidebar_row("Inbox", "Messages", 0);
  GtkWidget *mailboxes = gtk_label_new("Mailboxes");
  GtkWidget *favorites = gtk_label_new("Favorites");
  GtkWidget *people = gtk_label_new("Individuals");
  GtkWidget *divider = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget *groups = gtk_label_new("Groups");
  context->mailbox_list = gtk_list_box_new();
  context->thread_list = gtk_list_box_new();
  gtk_label_set_xalign(GTK_LABEL(mailboxes), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(favorites), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(people), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(groups), 0.0f);
  gtk_box_append(GTK_BOX(box), search);
  gtk_box_append(GTK_BOX(box), inbox);
  gtk_box_append(GTK_BOX(box), mailboxes);
  gtk_box_append(GTK_BOX(box), context->mailbox_list);
  gtk_box_append(GTK_BOX(box), favorites);
  gtk_box_append(GTK_BOX(box), people);
  gtk_box_append(GTK_BOX(box), context->thread_list);
  gtk_box_append(GTK_BOX(box), divider);
  gtk_box_append(GTK_BOX(box), groups);
  gtk_widget_set_size_request(box, 260, -1);
  return box;
}

static GtkWidget *make_main_stage(AppContext *context) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
  GtkWidget *title = gtk_label_new("Inbox");
  GtkWidget *subtitle = gtk_label_new("Email and SimpleX");
  GtkWidget *scroller = gtk_scrolled_window_new();
  context->inbox_list = gtk_list_box_new();
  gtk_label_set_xalign(GTK_LABEL(title), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(subtitle), 0.0f);
  gtk_widget_add_css_class(title, "view-title");
  gtk_widget_add_css_class(subtitle, "view-subtitle");
  gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), context->inbox_list);
  gtk_widget_set_vexpand(scroller, TRUE);
  gtk_box_append(GTK_BOX(box), title);
  gtk_box_append(GTK_BOX(box), subtitle);
  gtk_box_append(GTK_BOX(box), scroller);
  return box;
}

static GtkWidget *make_composer(AppContext *context) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  GtkWidget *simplex = gtk_check_button_new_with_label("SimpleX");
  GtkWidget *email = gtk_check_button_new_with_label("Email (open lock)");
  GtkWidget *send = gtk_button_new_with_label("Send");
  GtkWidget *subject = gtk_entry_new();
  context->composer = gtk_text_view_new();
  gtk_check_button_set_group(GTK_CHECK_BUTTON(email), GTK_CHECK_BUTTON(simplex));
  gtk_check_button_set_active(GTK_CHECK_BUTTON(simplex), TRUE);
  gtk_widget_add_css_class(send, "suggested-action");
  gtk_box_append(GTK_BOX(toolbar), simplex);
  gtk_box_append(GTK_BOX(toolbar), email);
  gtk_box_append(GTK_BOX(toolbar), send);
  gtk_entry_set_placeholder_text(GTK_ENTRY(subject), "Subject");
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(context->composer), GTK_WRAP_WORD_CHAR);
  gtk_widget_set_size_request(context->composer, -1, 96);
  gtk_box_append(GTK_BOX(box), toolbar);
  gtk_box_append(GTK_BOX(box), subject);
  gtk_box_append(GTK_BOX(box), context->composer);
  (void)context;
  return box;
}

static void app_action_activated(GSimpleAction *action, GVariant *parameter, gpointer user_data) {
  (void)parameter;
  AppContext *context = (AppContext *)user_data;
  const char *action_name = g_action_get_name(G_ACTION(action));
  if (g_strcmp0(action_name, "focus-new") == 0) { set_status(context, "focus new"); return; }
  if (g_strcmp0(action_name, "focus-inbox") == 0) { set_status(context, "focus inbox"); return; }
  if (g_strcmp0(action_name, "focus-mail") == 0) { set_status(context, "focus mail"); return; }
  if (g_strcmp0(action_name, "focus-archive") == 0) { set_status(context, "focus archive"); return; }
  if (g_strcmp0(action_name, "focus-favorites") == 0) { set_status(context, "focus favorites"); return; }
  if (g_strcmp0(action_name, "focus-people") == 0) { set_status(context, "focus people"); return; }
  if (g_strcmp0(action_name, "focus-groups") == 0) { set_status(context, "focus groups"); return; }
  if (g_strcmp0(action_name, "send-message") == 0) { set_status(context, "Use the native composer transport selector before sending."); return; }
  if (g_strcmp0(action_name, "archive-message") == 0) { set_status(context, "archive message"); return; }
  if (g_strcmp0(action_name, "delete-message") == 0) { set_status(context, "delete message"); return; }
  if (g_strcmp0(action_name, "toggle-star") == 0) { set_status(context, "toggle star"); return; }
  if (g_strcmp0(action_name, "mark-read") == 0) { set_status(context, "mark read"); return; }
  if (g_strcmp0(action_name, "open-settings") == 0) { set_status(context, "open settings"); return; }
  if (g_strcmp0(action_name, "choose-mail-root") == 0) { set_status(context, "choose mail root"); return; }
  if (g_strcmp0(action_name, "install-simplex-cli") == 0) { set_backend_status(context, "SimpleX CLI install action completed.", "install-simplex-cli", NULL, NULL); return; }
  if (g_strcmp0(action_name, "provision-simplex-identity") == 0) { set_backend_status(context, "Provisioned SimpleX identity.", "provision-simplex-identity", "default", NULL); return; }
  if (g_strcmp0(action_name, "configure-simplex-local-transport") == 0) { set_backend_status(context, "Enabled local SimpleX transport.", "configure-simplex-local-transport", "default", NULL); return; }
  if (g_strcmp0(action_name, "tick-simplex") == 0) { set_backend_status(context, "Checked SimpleX incoming queue.", "tick-simplex", NULL, NULL); return; }
  if (g_strcmp0(action_name, "bind-contact") == 0) { set_status(context, "bind contact"); return; }
  if (g_strcmp0(action_name, "compose-simplex") == 0) { set_status(context, "SimpleX selected as preferred secure transport."); return; }
  if (g_strcmp0(action_name, "compose-email") == 0) { set_status(context, "Email selected explicitly; open-lock warning treatment applies."); return; }
  if (g_strcmp0(action_name, "quit-app") == 0) { g_application_quit(G_APPLICATION(context->app)); return; }
  set_status(context, "Unsupported action.");
}

static void add_app_action(GtkApplication *app, AppContext *context, const char *name) {
  GSimpleAction *action = g_simple_action_new(name, NULL);
  g_signal_connect(action, "activate", G_CALLBACK(app_action_activated), context);
  g_action_map_add_action(G_ACTION_MAP(app), G_ACTION(action));
  g_object_unref(action);
}

static void setup_actions(GtkApplication *app, AppContext *context) {
  add_app_action(app, context, "focus-new");
  add_app_action(app, context, "focus-inbox");
  add_app_action(app, context, "focus-mail");
  add_app_action(app, context, "focus-archive");
  add_app_action(app, context, "focus-favorites");
  add_app_action(app, context, "focus-people");
  add_app_action(app, context, "focus-groups");
  add_app_action(app, context, "send-message");
  add_app_action(app, context, "archive-message");
  add_app_action(app, context, "delete-message");
  add_app_action(app, context, "toggle-star");
  add_app_action(app, context, "mark-read");
  add_app_action(app, context, "open-settings");
  add_app_action(app, context, "choose-mail-root");
  add_app_action(app, context, "install-simplex-cli");
  add_app_action(app, context, "provision-simplex-identity");
  add_app_action(app, context, "configure-simplex-local-transport");
  add_app_action(app, context, "tick-simplex");
  add_app_action(app, context, "bind-contact");
  add_app_action(app, context, "compose-simplex");
  add_app_action(app, context, "compose-email");
  add_app_action(app, context, "quit-app");
}

static void setup_menus(GtkApplication *app) {
  GMenu *menubar = g_menu_new();
  GMenu *app_menu = g_menu_new();
  g_menu_append(app_menu, "Preferences", "app.open-settings");
  g_menu_append(app_menu, "Quit", "app.quit-app");
  g_menu_append_submenu(menubar, "Stellar", G_MENU_MODEL(app_menu));

  GMenu *view_menu = g_menu_new();
  g_menu_append(view_menu, "Inbox", "app.focus-inbox");
  g_menu_append(view_menu, "Favorites", "app.focus-favorites");
  g_menu_append(view_menu, "People", "app.focus-people");
  g_menu_append(view_menu, "Groups", "app.focus-groups");
  g_menu_append_submenu(menubar, "View", G_MENU_MODEL(view_menu));

  GMenu *transport_menu = g_menu_new();
  g_menu_append(transport_menu, "Use SimpleX", "app.compose-simplex");
  g_menu_append(transport_menu, "Use Email", "app.compose-email");
  g_menu_append(transport_menu, "Check SimpleX", "app.tick-simplex");
  g_menu_append_submenu(menubar, "Transport", G_MENU_MODEL(transport_menu));
  gtk_application_set_menubar(app, G_MENU_MODEL(menubar));
  g_object_unref(menubar);
}

static void activate_action_button(GtkWidget *button, gpointer user_data) {
  (void)button;
  if (user_data != NULL) {
    g_action_activate(G_ACTION(user_data), NULL);
  }
}

static void activate(GtkApplication *app, gpointer user_data) {
  (void)user_data;
  AppContext *context = g_new0(AppContext, 1);
  context->app = app;
  context->mail_root = default_mail_root();

  context->window = gtk_application_window_new(app);
  gtk_window_set_title(GTK_WINDOW(context->window), "Stellar");
  gtk_window_set_default_size(GTK_WINDOW(context->window), 1120, 740);

  GtkWidget *header = gtk_header_bar_new();
  GtkWidget *simplex_button = gtk_button_new_from_icon_name("changes-prevent-symbolic");
  gtk_widget_set_tooltip_text(simplex_button, "Check SimpleX");
  gtk_header_bar_pack_start(GTK_HEADER_BAR(header), simplex_button);
  gtk_window_set_titlebar(GTK_WINDOW(context->window), header);

  setup_actions(app, context);
  setup_menus(app);

  GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  GtkWidget *paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget *sidebar_scroller = gtk_scrolled_window_new();
  GtkWidget *sidebar = make_sidebar(context);
  GtkWidget *stage = make_main_stage(context);
  GtkWidget *composer = make_composer(context);
  context->status_label = gtk_label_new("Ready");
  gtk_label_set_xalign(GTK_LABEL(context->status_label), 0.0f);

  gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(sidebar_scroller), sidebar);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sidebar_scroller), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_paned_set_start_child(GTK_PANED(paned), sidebar_scroller);
  gtk_paned_set_end_child(GTK_PANED(paned), stage);
  gtk_paned_set_position(GTK_PANED(paned), 280);
  gtk_widget_set_vexpand(paned, TRUE);

  gtk_box_append(GTK_BOX(root), paned);
  gtk_box_append(GTK_BOX(root), composer);
  gtk_box_append(GTK_BOX(root), context->status_label);
  gtk_window_set_child(GTK_WINDOW(context->window), root);
  refresh_from_backend(context);

  g_signal_connect(simplex_button, "clicked", G_CALLBACK(activate_action_button), g_action_map_lookup_action(G_ACTION_MAP(app), "tick-simplex"));

  gtk_window_present(GTK_WINDOW(context->window));
  (void)wizardry_app_ir;
}

int main(int argc, char **argv) {
  GtkApplication *app = gtk_application_new("app.stellar", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
  int status = g_application_run(G_APPLICATION(app), argc, argv);
  g_object_unref(app);
  return status;
}
