import fitz
import sys

def get_text_blocks(pdf_path):
    doc = fitz.open(pdf_path)
    for i in range(len(doc)):
        print(f"--- Page {i+1} ---")
        page = doc[i]
        blocks = page.get_text("blocks")
        for b in blocks:
            print(b)
            
get_text_blocks(sys.argv[1])
