import fitz
doc = fitz.open("test_redact.pdf")
blocks = doc[1].get_text("blocks")
for b in blocks:
    print(b)
