//
// (c) Technion IIT, The Faculty of Electrical and Computer Engineering, 2025
//
//  PRELIMINARY VERSION  -  23 March 2025
//  Updated: March 29, 2026 - Gadi Shavit 
//

/*
typedef struct packed {
    logic [3:0] note;
    logic [2:0] octave;
    logic [7:0] duration;
    logic [7:0] gap;
} note_struct;
*/

localparam int NOTES_IN_A_SONG = 256;
localparam int SOUND_MEM_SIZE = 4096;
localparam int SOUND_ADDR_W = $clog2(SOUND_MEM_SIZE);

typedef logic [SOUND_ADDR_W-1:0] song_addr_t; 

module melody_player_1
    (
    // Declare wires and regs :
 input logic resetN,
 input logic CLOCK_31p5,
 input logic startMelody,
 input logic [3:0] melodySelect, // request ID: banks 0..5, explicit restart 6
// input logic [15:0] songs_mem,		// input from songs.mif
 
 output logic [3:0] tone,
 output logic [2:0] octave,
 output logic EnableSoundOut,		// controls AUDIO module on/off 
 output logic melodyEnded       // indicates end of melody.  Also outputs to LED3      
 //output logic [11:0] note_address // output to audio MIF address 
 
  );   // serial number of current note. ( maximum 31 ). noteIndex determines freqIndex and note_length, via JueBox
 
 // songs.vh contain a table of songs, including note_base, octave, duration and gap	
//`include "songs.sv"

 // Maestro state machine declaration 
 enum logic [2:0] {s_idle, s_fetchWait, s_loadNote, s_playNote, s_gap, s_ended} SM_Maestro;
 logic [3:0] activeBank;
 logic [2:0] activePriority;
 logic [15:0] noteWord;

 // Victory > Defeat > Cursed > Sapphire > Ruby > restart > direction.
 // Restart is an explicit sequence cancellation, even during terminal audio.
 function automatic logic [2:0] requestPriority(input logic [3:0] requestID);
     case (requestID)
         4'd0: requestPriority = 3'd7;
         4'd1: requestPriority = 3'd6;
         4'd3: requestPriority = 3'd5;
         4'd2: requestPriority = 3'd4;
         4'd5: requestPriority = 3'd3;
         4'd6: requestPriority = 3'd2;
         4'd4: requestPriority = 3'd1;
         default: requestPriority = 3'd0;
     endcase
 endfunction
 wire acceptRequest = startMelody && (requestPriority(melodySelect) != 0) &&
     ((melodySelect == 4'd6) || (SM_Maestro == s_idle) ||
      (SM_Maestro == s_ended) || (requestPriority(melodySelect) > activePriority));

	// parameters declarations
	logic [11:0] note_address;
	 logic [15:0] songs_mem;
	logic [4:0] noteTimeCounter; // count down timer ( maximum 1024 )
   logic [4:0] noteDuration;    
   logic [4:0] gapDuration;     // time of gap between notes in msec
   logic hundredthSecPulse; // A short pulse, once every 1/100 second. 

	// interface signals to the list of songs
	logic [7:0] noteIndex;
	lpm_rom #(
    .LPM_WIDTH(16),
    .LPM_WIDTHAD(12),
	 .LPM_NUMWORDS(4096),
    .LPM_FILE("RTL/AUDIO/songs.mif"),
	   .LPM_TYPE               ("LPM_ROM"),
      .LPM_ADDRESS_CONTROL    ("REGISTERED"), 
		.LPM_OUTDATA            ("UNREGISTERED"), 
		.AUTO_CARRY_CHAINS      ("ON"),
		.AUTO_CASCADE_BUFFERS   ("ON"),
	   .INTENDED_DEVICE_FAMILY ("Cyclone V")  
) rom_inst (
    .address(note_address),
	 .inclock(CLOCK_31p5),
	// .outclock(clk),
    .q(songs_mem)
);
  //----------------------------------------------------------------------------------------------------------
  // Instances of slow counter.  pulse every 10 mSec
  //----------------------------------------------------------------------------------------------------------									  									  								 
   Mili_sec_counter #(.SIMULATION_MODE(1'h0), .mSecPerTick(30), .PLLClock(315)) mili_sec_counter_inst 
	                     (.clk(CLOCK_31p5),   
								 .resetN(resetN),
								 .turbo(1'h0),   
								 .hundredth_sec(hundredthSecPulse) );
								 
	//----------------------------------------------------------------------------------------------------------								 					 	 
	//   syncronous code,  executed once every clock to update the current state and outputs 
	//----------------------------------------------------------------------------------------------------------	
	always_ff @(posedge CLOCK_31p5 or negedge resetN) // State machine logic 
		begin   
		if ( !resetN ) begin // Asynchronic reset, initialize the state machine 
			SM_Maestro <= s_idle;
			noteIndex <= 8'b0 ;
			noteTimeCounter  <= 5'd0 ;
			activeBank <= 4'd4;
			activePriority <= 3'd0;
			noteWord <= 16'd0;
			EnableSoundOut <= 1'b0 ;
			melodyEnded <= 1'b0 ;
		end // asynch
		else begin
            melodyEnded <= 1'b0;
            if (acceptRequest) begin
                activeBank <= (melodySelect == 4'd6) ? 4'd4 : melodySelect;
                activePriority <= requestPriority(melodySelect);
                noteIndex <= 8'd0;
                noteTimeCounter <= 5'd0;
                EnableSoundOut <= 1'b0;
                SM_Maestro <= s_fetchWait;
            end else begin
                case (SM_Maestro)
                    s_idle: begin
                        EnableSoundOut <= 1'b0;
                        activePriority <= 3'd0;
                    end
                    // Address changes on acceptance/index advance. At this edge
                    // the ROM registers that address; use its word NEXT edge.
                    s_fetchWait: SM_Maestro <= s_loadNote;
                    s_loadNote: begin
                        if (noteDuration == 5'd0) begin
                            EnableSoundOut <= 1'b0;
                            noteTimeCounter <= 5'd0;
                            activePriority <= 3'd0;
                            melodyEnded <= 1'b1;
                            SM_Maestro <= s_ended;
                        end else begin
                            noteWord <= songs_mem;
                            noteTimeCounter <= noteDuration;
                            EnableSoundOut <= 1'b1;
                            SM_Maestro <= s_playNote;
                        end
                    end
                    s_playNote: if (hundredthSecPulse) begin
                        if (noteTimeCounter > 5'd1)
                            noteTimeCounter <= noteTimeCounter - 5'd1;
                        else begin
                            EnableSoundOut <= 1'b0;
                            noteTimeCounter <= gapDuration;
                            if (gapDuration != 5'd0)
                                SM_Maestro <= s_gap;
                            else begin
                                noteIndex <= noteIndex + 8'd1;
                                SM_Maestro <= s_fetchWait;
                            end
                        end
                    end
                    s_gap: if (hundredthSecPulse) begin
                        if (noteTimeCounter > 5'd1)
                            noteTimeCounter <= noteTimeCounter - 5'd1;
                        else begin
                            noteTimeCounter <= 5'd0;
                            noteIndex <= noteIndex + 8'd1;
                            SM_Maestro <= s_fetchWait;
                        end
                    end
                    s_ended: SM_Maestro <= s_idle;
                    default: begin
                        SM_Maestro <= s_idle;
                        EnableSoundOut <= 1'b0;
                        noteTimeCounter <= 5'd0;
                        activePriority <= 3'd0;
                    end
                endcase
            end
		end // if reset else
	end // always_ff state machine 

	//assign song_index  = base_offset + noteIndex;
	//assign note_address[11:8] = melodySelect;
	//assign note_address[7:0] = noteIndex;
	assign note_address = {activeBank,noteIndex};
//	assign tone        	= all_songs[song_index].note;
//	assign octave      	= all_songs[song_index].octave;
//	assign noteDuration  = all_songs[song_index].duration;	// in units of ? msec
//	assign gapDuration  	= all_songs[song_index].gap;		   // in units of ? msec

	assign tone        	= noteWord[15:12];
	assign octave   		= {{1'b0},{noteWord[11:10]}} + 3'd3;
	assign noteDuration  = songs_mem[9:5];
	assign gapDuration  	= noteWord[4:0];
endmodule

