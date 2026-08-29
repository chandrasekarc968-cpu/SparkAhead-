import fitz

def create_presentation():
    doc = fitz.open(r"C:\Users\Chand\Downloads\TEAM NAME.pptx_20260828_145247_0000.pdf")

    # Font settings
    fontname = "helv"
    fontsize = 28
    bullet_font = "helv"
    bullet_char = chr(0x2022) # Bullet character
    color = (0, 0, 0)
    
    # -----------------------------
    # Slide 1: TITLE PAGE
    # -----------------------------
    page1 = doc[0]
    # "TEAM NAME:" is at y=363. Insert at x=350, y=363
    page1.insert_text((350, 360), "YEAGERIST", fontsize=32, fontname=fontname, color=color)
    # "PROBELM STATEMENT NO: " ends at x=564. Insert at x=580, y=453
    page1.insert_text((580, 453), "PS02", fontsize=32, fontname=fontname, color=color)
    # "PROBLEM STATEMENT TITLE:" ends at 597. Insert at x=610, y=535
    page1.insert_text((610, 535), "Multi-Master AXI4-Lite Arbiter", fontsize=32, fontname=fontname, color=color)
    # "PS Category-" is already there. Wait, is it?
    # Actually, the user says "Fill only the blank fields... PS Category: Software/Hardware". 
    # But it already says "PS Category-\nSoftware/Hardware\n". We don't need to add it, but just in case, we won't touch it.

    # -----------------------------
    # Slide 2: PROBLEM STATEMENT
    # -----------------------------
    page2 = doc[1]
    page2.add_redact_annot(fitz.Rect(100, 320, 1000, 550), fill=None)
    page2.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
    
    bullets2 = [
        "Four SoC masters may request the same shared bus simultaneously.",
        "Uncontrolled contention can corrupt transfers or misroute responses.",
        "Slow peripherals create back-pressure and unpredictable latency.",
        "Fixed priority can starve lower-priority masters."
    ]
    y = 350
    for b in bullets2:
        page2.insert_text((150, y), f"{bullet_char} {b}", fontsize=fontsize, fontname=bullet_font, color=color)
        y += 40

    # -----------------------------
    # Slide 3: YOUR SOLUTION
    # -----------------------------
    page3 = doc[2]
    page3.add_redact_annot(fitz.Rect(100, 300, 1000, 550), fill=None)
    page3.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
    
    bullets3 = [
        "Project name: AXI-GUARD",
        "A protocol-safe 4-master, 2-slave AXI4-Lite interconnect.",
        "Separate read/write arbiters allow concurrent traffic.",
        "Weighted round-robin provides controlled priority.",
        "Aging prevents indefinite starvation.",
        "Registered ownership keeps responses with the correct master.",
        "A default slave returns DECERR for unmapped addresses."
    ]
    y = 330
    for b in bullets3:
        page3.insert_text((120, y), f"{bullet_char} {b}", fontsize=24, fontname=bullet_font, color=color)
        y += 35

    # -----------------------------
    # Slide 4: ARCHITECTURAL BLOCK DIAGRAM
    # -----------------------------
    page4 = doc[3]
    page4.add_redact_annot(fitz.Rect(90, 380, 800, 500), fill=None)
    page4.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)

    # Draw Diagram
    # Center is ~720 (width 1440). Y start around 450.
    # Four Masters on left
    m_y = 420
    for i, name in enumerate(["Master 0: Real-time controller", "Master 1: CPU", "Master 2: DMA", "Master 3: Debug processor"]):
        page4.draw_rect(fitz.Rect(100, m_y, 350, m_y+40), color=(0,0,0), fill=(0.9,0.9,0.9))
        page4.insert_text((110, m_y+25), name, fontsize=16, fontname=fontname, color=color)
        # Arrow to center
        page4.draw_line((350, m_y+20), (450, m_y+20), color=(0,0,0))
        m_y += 60

    # Center block (Arbiter)
    page4.draw_rect(fitz.Rect(450, 420, 850, 640), color=(0,0,0), fill=(0.9,0.9,0.9))
    page4.insert_text((550, 450), "Read & Write Arbitration", fontsize=20, fontname="helv", color=color)
    page4.insert_text((480, 490), "• Weighted Round-Robin", fontsize=18, fontname=fontname, color=color)
    page4.insert_text((480, 530), "• Aging Logic", fontsize=18, fontname=fontname, color=color)
    page4.insert_text((480, 570), "• Ownership Tracking", fontsize=18, fontname=fontname, color=color)
    page4.insert_text((480, 610), "• Address Decoder", fontsize=18, fontname=fontname, color=color)

    # Slaves on right
    # Arrow to slaves
    page4.draw_line((850, 480), (950, 480), color=(0,0,0))
    page4.draw_line((850, 540), (950, 540), color=(0,0,0))
    page4.draw_line((850, 600), (950, 600), color=(0,0,0))

    page4.draw_rect(fitz.Rect(950, 460, 1300, 500), color=(0,0,0), fill=(0.9,0.9,0.9))
    page4.insert_text((960, 485), "Slave 0: Control/Status", fontsize=16, fontname=fontname, color=color)

    page4.draw_rect(fitz.Rect(950, 520, 1300, 560), color=(0,0,0), fill=(0.9,0.9,0.9))
    page4.insert_text((960, 545), "Slave 1: Memory/Sensor", fontsize=16, fontname=fontname, color=color)

    page4.draw_rect(fitz.Rect(950, 580, 1300, 620), color=(0,0,0), fill=(0.9,0.9,0.9))
    page4.insert_text((960, 605), "Default Slave: DECERR", fontsize=16, fontname=fontname, color=color)

    # -----------------------------
    # Slide 5: PURPOSE OF BLOCKS
    # -----------------------------
    page5 = doc[4]
    page5.add_redact_annot(fitz.Rect(80, 330, 1400, 650), fill=None)
    page5.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
    
    bullets5 = [
        "Input: Captures independent AXI AW, W and AR requests.",
        "Processing: Arbitrates, decodes addresses and tracks ownership.",
        "Output: Returns B/R responses to the originating master.",
        "Architecture choice: Separate read/write paths preserve concurrency and ordering.",
        "Trade-off: Extra buffering adds area, but simplifies correctness and verification."
    ]
    y = 350
    for b in bullets5:
        page5.insert_text((100, y), f"{bullet_char} {b}", fontsize=26, fontname=bullet_font, color=color)
        y += 45

    # -----------------------------
    # Slide 6: OUTPUTS AND RESULTS
    # -----------------------------
    page6 = doc[5]
    page6.add_redact_annot(fitz.Rect(70, 470, 1350, 650), fill=None)
    page6.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
    
    bullets6 = [
        "AXI VALID/READY behavior remains stable under back-pressure.",
        "AW and W channels work independently.",
        "Read and write traffic can progress concurrently.",
        "Aging prevents starvation under sustained contention.",
        "Invalid addresses return DECERR.",
        "Verification includes simulation, assertions, formal checks and synthesis."
    ]
    y = 480
    for b in bullets6:
        page6.insert_text((200, y), f"{bullet_char} {b}", fontsize=24, fontname=bullet_font, color=color)
        y += 35

    # -----------------------------
    # Slide 7: RESEARCH AND REFERENCES
    # -----------------------------
    page7 = doc[6]
    page7.add_redact_annot(fitz.Rect(300, 370, 1200, 450), fill=None)
    page7.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
    
    bullets7 = [
        "ARM AMBA AXI4-Lite Protocol Specification, IHI 0022.",
        "Project repository: https://github.com/chandrasekarc968-cpu/SparkAhead-",
        "Yosys synthesis documentation.",
        "OpenROAD physical-design flow documentation."
    ]
    y = 380
    for b in bullets7:
        page7.insert_text((150, y), f"{bullet_char} {b}", fontsize=26, fontname=bullet_font, color=color)
        y += 45

    # -----------------------------
    # Slide 8: DELETE
    # -----------------------------
    doc.delete_page(7)

    # Save
    doc.save("YEAGERIST_PS02_final.pdf")

create_presentation()
