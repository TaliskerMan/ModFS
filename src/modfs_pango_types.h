/*
 * modfs_pango_types.h — stand-ins for the few Pango types FSearch's search
 * core mentions in its (GUI-only) highlight API.
 *
 * ModFS change (2026-10-16): ModFS never shows match highlights, so the core
 * doesn't need Pango, GTK or their font/graphics stack at all. With
 * MODFS_NO_PANGO defined (see src/meson.build) these opaque types replace
 * <pango/pango-attributes.h> and the highlight calls become no-ops. That keeps
 * the macOS app free of those libraries and lets the core be built for older
 * macOS versions.
 *
 * Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.
 */
#pragma once

#ifdef MODFS_NO_PANGO

typedef struct _PangoAttrList PangoAttrList;
/* Only the fields FSearch's matcher code sets; allocated with g_new0() by
 * the stand-in pango_attr_weight_new() and freed when "added" to a list. */
typedef struct _PangoAttribute {
    unsigned int start_index;
    unsigned int end_index;
} PangoAttribute;
typedef int PangoWeight;
#define PANGO_WEIGHT_BOLD 700

#else

#include <pango/pango-attributes.h>

#endif
