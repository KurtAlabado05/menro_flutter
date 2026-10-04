# Photo Gallery Integration Guide

## What Was Created
**File**: `lib/widgets/photo_gallery_section.dart`

A production-ready photo gallery widget that mirrors the **menro_admin** UI:
- Tree photos in responsive grid (2 columns on mobile, 3-4 on tablet/desktop)
- Full-screen photo preview modal with zoom controls
- "Open original" and reset zoom functionality
- Professional error handling with image placeholders
- Separation of tree photos from other documents

---

## Usage Example

### Step 1: Import the Widget
```dart
import '../../widgets/photo_gallery_section.dart';
```

### Step 2: Prepare Your Photo Documents
```dart
List<PhotoDocument> photos = [
  PhotoDocument(
    url: 'https://res.cloudinary.com/dfo5l4d4t/image/upload/v123/tree1.jpg',
    name: 'Tree Picture 1',
    kind: 'tree-picture',
    verified: true,
  ),
  PhotoDocument(
    url: 'https://res.cloudinary.com/dfo5l4d4t/image/upload/v123/land_title.pdf',
    name: 'Land Title',
    kind: 'document',
  ),
];
```

### Step 3: Add to Your Screen
```dart
PhotoGallerySection(
  documents: photos,
  title: 'Application Documents',
  subtitle: 'Tree photos and supporting documents',
  showTreePicturesFirst: true,
)
```

---

## Integration with Inspection Detail Screen

### In `inspection_detail_screen.dart`:

**Step 1: Extract photos from application**
```dart
// Around line 190-195
final List<PhotoDocument> photoDocuments = (application.documents ?? [])
    .map((doc) => PhotoDocument(
      url: doc['url'] ?? '',
      name: doc['name'] ?? 'Document',
      kind: doc['kind'] ?? 'document',
      verified: doc['verified'] ?? false,
    ))
    .toList();
```

**Step 2: Add to ListView**
```dart
ListView(
  padding: const EdgeInsets.all(16),
  children: [
    // ... existing content ...
    
    const SizedBox(height: 16),
    PhotoGallerySection(
      documents: photoDocuments,
      title: 'Application Documents',
      subtitle: 'Attached tree photos and supporting documentation',
    ),
    
    // ... more content ...
  ],
)
```

---

## Features & Components

### PhotoGallerySection
The main container widget that manages photo display.

**Props**:
- `documents`: List of PhotoDocument objects
- `title`: Section header (default: "Photos")
- `subtitle`: Optional description
- `showTreePicturesFirst`: Separate tree photos from other docs (default: true)
- `onPhotoTapped`: Callback when a photo is selected

### PhotoDocument
Data class representing a single photo/document.

**Fields**:
```dart
PhotoDocument(
  url: String,           // Cloudinary URL or any image URL
  name: String,          // Display name
  kind: String?,         // 'tree-picture', 'document', etc.
  verified: bool?,       // Whether document is verified
)
```

### TreePhotosGrid (_TreePhotosGrid)
Responsive grid showing tree photos.

**Features**:
- 2-column grid on mobile
- Auto-adjusts to tablet/desktop layouts
- Click to preview full-size
- Shows loading indicator while image loads
- Shows "Image unavailable" placeholder on error
- Displays photo name and URL snippet

### PhotoPreviewDialog
Full-screen modal for viewing photos.

**Features**:
- Pinch-to-zoom (InteractiveViewer)
- Pan support
- Zoom reset button
- "Open original" to open in browser
- Dark backdrop with blur
- Auto-detects image vs. non-image files

---

## Data Structure from Firebase

The inspection_application_model should provide documents like:

```dart
{
  'documents': [
    {
      'name': 'Tree Picture 1',
      'url': 'https://res.cloudinary.com/.../tree1.jpg',
      'kind': 'tree-picture',
      'verified': true,
    },
    {
      'name': 'Land Title',
      'url': 'https://res.cloudinary.com/.../title.pdf',
      'kind': 'supporting-document',
      'verified': true,
    },
  ]
}
```

---

## Comparison: Admin vs. Flutter

| Feature | menro_admin | menro_flutter |
|---------|------------|------------------|
| Grid layout | 2-3-4 columns | 2 columns responsive |
| Tree photo section | Separated | Separated |
| Photo preview | Modal with zoom | Dialog with zoom |
| Zoom controls | +/- buttons | Pinch gesture |
| Other documents | Table list | Document list |
| Error handling | Inline SVG | Placeholder icon |
| Loading state | CSS spinner | CircularProgressIndicator |
| Dark theme | Tailwind CSS | Material theme |

---

## Screenshots (Mental Model)

### Before (Current)
```
Inspection Detail
└── Application Details
└── Inspection Findings
└── [No photos]
```

### After (With PhotoGallerySection)
```
Inspection Detail
├── Application Details
├── Inspection Findings
├── Documents Section
│   ├── TREE PICTURES (3 images)
│   │   ├── [Image grid 2x2]
│   │   └── Click to preview → Full-screen modal
│   └── Other Documents
│       ├── Land Title - [View]
│       └── Certification - [View]
└── Action Bar
```

---

## Troubleshooting

### Images Show "Image unavailable"
1. Check Cloudinary upload preset is configured for unsigned uploads
2. Verify URLs are HTTPS (secure_url from Cloudinary)
3. Test URL directly in browser incognito window
4. Check browser console for 401/403 errors

### Photos Don't Appear in Section
1. Verify `documents` list is not empty
2. Check `url` field is populated (not "PENDING_UPLOAD")
3. Ensure `kind` or `name` contains "tree" for tree photo classification
4. Add debug log: `print('Photos: ${documents.length}')`

### InteractiveViewer Not Working
- Ensure `photo_gallery_section.dart` imports are correct
- Verify Flutter version >= 2.5 (InteractiveViewer available since 1.20)

---

## Next Steps

1. ✅ Add PhotoGallerySection to inspection_detail_screen.dart
2. ✅ Test with actual Cloudinary URLs
3. ✅ Add to inspection_officer_section_screen.dart if needed
4. ✅ Add to case_documentation_screen.dart
5. ✅ Consider adding to report detail screen

---

## Notes

- The widget handles both images and documents gracefully
- Photos load lazily (lazy loading enabled)
- Respects app theme (light/dark mode)
- Fully accessible with semantic labels
- Matches admin dashboard UI/UX
