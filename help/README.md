# Help

`en_US/*.xml` are the per-verb help pages (generated from the macro headers with
`help_from_sci`, one per public `db*` verb). They are committed as source.

To compile them into the in-Scilab help (`help dbConnect`, etc.), build the jar from the
**Scilab GUI** (STD mode):

```scilab
exec help/builder_help.sce;
```

The jar build uses Scilab's Java-based doc compiler, so run it in the GUI — on this Scilab
build headless Java interop hangs. For a quick text reference that needs no build, see
[`../docs/REFERENCE.md`](../docs/REFERENCE.md).
