# Easels

Easels is a local AppKit editor hosted over an owned native Dia tab. It does not
start a web server or load a web application. The tab's local HTML page supplies
a durable identity and fallback title; the editor uses NSView, NSScrollView,
NSTextView and ImageIO. Ordinary web pages never receive an editor overlay.

## Documents and recovery

Documents live beneath `DiaPatches/Easels/Documents/<UUID>` in Application
Support. JSON stores versioned canvas objects, a designated title object and
asset references. Images are copied into the document, so deleting a board does
not delete the imported source file. Writes are serialized and atomic, with a
recovery copy. Library summaries avoid decoding all documents for the catalog.

Delete Easel moves its directory to `Easels/Trash`, closes matching native tab
placements, and leaves unrelated tabs alone. Library's Recently Deleted view
offers Restore Easel, including after restart. Removing an Easel from the
sidebar closes its tab placement without deleting the saved document. There is
no automatic trash expiry or permanent-delete control.

The designated heading supplies the document name. It starts as Untitled;
other text never becomes the title. Rename updates or recreates that heading.
The full heading is retained while tab and catalog labels may truncate it.

## Interaction

Tools: V select, I image, T text, O oval, R rectangle, A arrow, P pen. Tool
shortcuts yield to native text editing. Shift constrains shapes and drawing;
Option bypasses gentle alignment snapping. Native text editing, clipboard,
undo/redo, selection and object context menus use the same document model.

The board has fixed logical coordinates. Window width scales the whole slide
uniformly, including input conversion, rather than reflowing individual objects.
The drawing-color control sets the next drawing color; images are not colorable.
Tools remember their chosen colors and text retains the last font/size. Arrow
selection exposes directed endpoint handles. Selection handles and snap radii
stay constant in screen points as the slide scales.

## Resource behavior and verification

Image decoding runs on bounded workers with bounded thumbnail caches. Animated
images advance only while visible; idle canvases do not run an animation loop.
Catalog work is asynchronous and generation checked. Shared document identity
keeps multiple editor placements coherent. Completed gestures merge independent
changes made in another placement. Conflicting stale group gestures cancel as a
whole, preserving newer objects rather than overwriting or resurrecting them.

Run `scripts/check-easels` for store/recovery, geometry, editor, image, catalog,
hosting and scoped native-menu checks. Run `scripts/check-sidebar-library` for
Library lifecycle, continuous motion, page-frame restoration and context routing.
Some AppKit fixtures require WindowServer access. Passing isolated fixtures does
not replace live horizontal/vertical, input-method and performance checks.

Sharing, collaboration, live web captures, Arc import and the extra Split tool
are intentionally outside the current implementation scope.

Oval and Rectangle expose a short-lived vertical Filled/Outline palette above
the corresponding toolbar button. The first default is Filled; subsequent choices
are stored independently in the existing DiaTweaks preferences suite. Selected
shapes can change style with one undoable transaction. Options dismiss when a
gesture starts or after a few seconds. The color controls use the same native
popover material as the toolbar; selected-object color remains beside the object.

Native address fields present the local board name while retaining the durable
file URL internally. Replacing the displayed name with a new query keeps native
navigation behavior; submitting the unchanged name dismisses editing. Ordinary
website fields and canvas text are outside this presentation scope.

GIF callbacks from released playback generations are discarded after teardown.

Easel Library collections, including Recently Deleted, follow the native browser profile. New boards and imported copies belong to the destination profile; spaces sharing a profile share its boards. Existing boards without ownership remain in the original profile (Profile 1), without moving or deleting their files. Media remains shared across profiles.
