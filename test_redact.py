import fitz
import sys

doc = fitz.open(sys.argv[1])
page = doc[1]
# Redact "Real-world problem"
rect = fitz.Rect(257, 324, 762, 396)
page.add_redact_annot(rect)
page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
doc.save("test_redact.pdf")
