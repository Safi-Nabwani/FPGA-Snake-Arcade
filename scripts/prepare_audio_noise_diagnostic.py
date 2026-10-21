"""Create an isolated diagnostic checkout; never edits production files.

Uses the pre-investigation source snapshot, including the user's dirty QSF/BDF.
Only adds read-only JTAG instrumentation to three copied audio modules.
"""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "db/audio_noise_investigation_baseline/files"
DEST = ROOT / "db/audio_noise_diagnostic/source"


def inject(path, text):
    target = DEST / path
    original = target.read_text()
    if original.count("endmodule") != 1:
        raise ValueError(f"Unexpected module structure: {path}")
    target.write_text(original.replace("endmodule", text + "\nendmodule"))


def probe(index, payload, clock="clk"):
    return f"""
    audio_noise_probe #(.INDEX({index})) diagnostic_probe(
        .clk({clock}),.resetN(resetN),.payload({payload}),
        .testTck(1'b0),.testIr(1'b0),.testCapture(1'b0),
        .testShift(1'b0),.testTdi(1'b0),.testTdo());
"""


def main():
    if DEST.exists():
        raise SystemExit("Diagnostic source already exists; refusing overwrite")
    shutil.copytree(BASE, DEST)
    (DEST / "diagnostics").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "diagnostics/audio_noise_probe.sv", DEST / "diagnostics/audio_noise_probe.sv")
    player = """
    logic [31:0] diagnosticCycles;
    logic [15:0] diagnosticAccepted,diagnosticEnded;
    always_ff @(posedge CLOCK_31p5 or negedge resetN)begin
        if(!resetN)begin diagnosticCycles<=0;diagnosticAccepted<=0;diagnosticEnded<=0;end
        else begin
            diagnosticCycles<=diagnosticCycles+1'b1;
            if(acceptRequest)diagnosticAccepted<=diagnosticAccepted+1'b1;
            if(melodyEnded)diagnosticEnded<=diagnosticEnded+1'b1;
        end
    end
""" + probe(80, "{diagnosticAccepted,diagnosticEnded,noteWord,songs_mem,8'd0,noteIndex,noteTimeCounter,noteDuration,gapDuration,hundredthSecPulse,18'd0,acceptRequest,startMelody,melodyEnded,EnableSoundOut,SM_Maestro,activeBank,activePriority,diagnosticCycles,32'h41555050}", "CLOCK_31p5")
    inject("RTL/AUDIO/melody_player_1.sv", player)
    sine = """
    logic [31:0] diagnosticCycles,diagnosticChanges,diagnosticLastChange;
    logic [15:0] diagnosticPrevious;
    always_ff @(posedge clk or negedge resetN)begin
        if(!resetN)begin diagnosticCycles<=0;diagnosticChanges<=0;diagnosticLastChange<=0;diagnosticPrevious<=0;end
        else begin
            diagnosticCycles<=diagnosticCycles+1'b1;diagnosticPrevious<=Q;
            if(Q!=diagnosticPrevious)begin diagnosticChanges<=diagnosticChanges+1'b1;diagnosticLastChange<=diagnosticCycles;end
        end
    end
""" + probe(81, "{diagnosticLastChange,diagnosticChanges,tmp8bit,8'd0,Q,16'd0,ADDR,4'd0,volume_level,volume_d,volume,diagnosticCycles,32'h41555053}")
    inject("RTL/AUDIO/SinTable.sv", sine)
    divider = """
    logic [31:0] diagnosticCycles,diagnosticPulses,diagnosticLastPulse;
    always_ff @(posedge clk or negedge resetN)begin
        if(!resetN)begin diagnosticCycles<=0;diagnosticPulses<=0;diagnosticLastPulse<=0;end
        else begin
            diagnosticCycles<=diagnosticCycles+1'b1;
            if(slowEnPulse)begin diagnosticPulses<=diagnosticPulses+1'b1;diagnosticLastPulse<=diagnosticCycles;end
        end
    end
""" + probe(82, "{diagnosticLastPulse,diagnosticPulses,18'd0,preScaleValue,slowEnPulse_d,slowEnPulse,counter,diagnosticCycles,32'h41555044}")
    inject("RTL/AUDIO/prescaler.sv", divider)
    qsf = DEST / "Lab1Demo.qsf"
    # The archived pre-repair QSF permits debug outputs on arbitrary board
    # pads. Any future diagnostic build must include the proven pin correction.
    qsf.write_text(qsf.read_text() + '\nset_instance_assignment -name VIRTUAL_PIN ON -to "BG_RGB[*]"\n'
                   'set_instance_assignment -name VIRTUAL_PIN ON -to borderDR\n'
                   'set_global_assignment -name SYSTEMVERILOG_FILE diagnostics/audio_noise_probe.sv\n')
    print(f"Diagnostic source: {DEST}")
    print("Production source/QSF/SOF and approved rollback SOF unchanged.")


if __name__ == "__main__":
    main()
