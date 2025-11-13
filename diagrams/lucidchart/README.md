# Lucidchart Diagrams

**Workspace:** [Add your Lucidchart workspace URL]  
**Access:** Contact project maintainer for access

---

## Purpose

This directory contains **optional** enhanced diagram exports from Lucidchart for presentation and stakeholder communication.

**Note:** The Mermaid diagrams in the parent `diagrams/` directory are the **source of truth** and are mandatory. Lucidchart diagrams are optional enhancements.

---

## Files in This Directory

| File | Purpose | Last Updated | Lucidchart Link |
|------|---------|--------------|-----------------|
| `data-flow.png` | Data flow diagram export | (not yet created) | [Edit in Lucidchart](https://lucid.app/) |
| `network-flow.png` | Network architecture export | (not yet created) | [Edit in Lucidchart](https://lucid.app/) |
| `auth-flow.png` | Auth flow export | (not yet created) | [Edit in Lucidchart](https://lucid.app/) |

---

## Editing Workflow

1. **Edit online:** Click Lucidchart link above (requires Lucidchart account)
2. **Export:** File → Export → PNG (2x resolution)
3. **Save:** Replace PNG file in this directory
4. **Sync:** Update corresponding Mermaid diagram in parent directory if structure changed
5. **Commit:** Add to git with meaningful message

---

## Synchronization Rules

### When to update BOTH Mermaid and Lucidchart:
- ✅ New component added
- ✅ Component removed
- ✅ Relationship changed
- ✅ Flow direction changed
- ✅ Major architectural change

### Lucidchart only (no Mermaid update needed):
- ✅ Visual styling (colors, icons)
- ✅ Layout improvements
- ✅ Adding explanatory text
- ✅ Icon/image updates
- ✅ Formatting changes

### Monthly review:
- Ensure Lucidchart exports are current
- Verify structure matches Mermaid diagrams
- Refresh stale exports

---

## Export Settings

**Recommended PNG export settings:**
- **Resolution:** 2x (for Retina displays)
- **Background:** White
- **Include:** Entire page
- **Format:** PNG (better for diagrams than JPEG)

**For presentations:** Export as SVG (scalable)

---

## Quick Start

To add Lucidchart diagrams:

1. Create diagrams in Lucidchart workspace
2. Export each as PNG (2x resolution)
3. Save in this directory with matching names:
   - `data-flow.png`
   - `network-flow.png`
   - `auth-flow.png`
4. Update table above with links and dates
5. Commit to git

---

**Note:** Lucidchart files are optional. The mandatory Mermaid diagrams in the parent directory are sufficient for all documentation needs.
