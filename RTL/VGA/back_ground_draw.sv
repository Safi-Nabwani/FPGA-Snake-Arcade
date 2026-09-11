module back_ground_draw (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic [10:0] pixelX,
	input logic [10:0] pixelY,

//------------- Outputs -----------

	output logic [7:0] BG_RGB,
	output logic borderDR,
	output logic obstacle_DR

);

//------------- Arena Parameters -----------

localparam int TOP_HEIGHT = 88;

localparam int ARENA_LEFT   = 128;
localparam int ARENA_TOP    = 88;
localparam int ARENA_RIGHT  = 512;
localparam int ARENA_BOTTOM = 472;

localparam int TILE_SIZE = 24;

//------------- Region Values -----------

//Define params to improve clearity
localparam logic [1:0] REGION_TOP   = 2'd0;
localparam logic [1:0] REGION_ARENA = 2'd1;
localparam logic [1:0] REGION_WOOD  = 2'd2;

//------------- Arena Tile Values -----------

//Define params to improve clearity
localparam logic [1:0] TILE_GRASS = 2'b00;
localparam logic [1:0] TILE_STONE = 2'b01;
localparam logic [1:0] TILE_ROCK  = 2'b10;

//------------- Arena Tile Map -----------
//
// 00 = grass
// 01 = stone
// 10 = rock / obstacle
//
// Each row has 16 tiles.
// Each tile uses 2 bits, so each row is 32 bits.

localparam logic [31:0] ARENA_ROW_0  = 32'b00_01_00_01_00_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_1  = 32'b01_00_01_00_01_00_01_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_2  = 32'b00_01_00_01_00_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_3  = 32'b01_00_01_00_01_00_01_00_01_00_01_10_10_00_01_00;
localparam logic [31:0] ARENA_ROW_4  = 32'b00_01_00_01_00_01_00_01_00_01_00_10_10_01_00_01;
localparam logic [31:0] ARENA_ROW_5  = 32'b01_00_01_00_01_00_01_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_6  = 32'b00_01_00_01_00_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_7  = 32'b01_00_01_00_01_00_01_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_8  = 32'b00_01_00_01_00_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_9  = 32'b01_00_01_10_10_00_01_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_10 = 32'b00_01_00_10_10_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_11 = 32'b01_00_01_10_10_10_10_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_12 = 32'b00_01_00_10_10_10_10_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_13 = 32'b01_00_01_00_01_00_01_00_01_00_01_00_01_00_01_00;
localparam logic [31:0] ARENA_ROW_14 = 32'b00_01_00_01_00_01_00_01_00_01_00_01_00_01_00_01;
localparam logic [31:0] ARENA_ROW_15 = 32'b01_00_01_00_01_00_01_00_01_00_01_00_01_00_01_00;

//------------- Area Detection -----------

logic insideTop;
logic insideArena;

assign insideTop =
	(pixelY < TOP_HEIGHT);

assign insideArena =
	(pixelX >= ARENA_LEFT)   &&
	(pixelX <  ARENA_RIGHT)  &&
	(pixelY >= ARENA_TOP)    &&
	(pixelY <  ARENA_BOTTOM);

//------------- Coordinate Calculations -----------

logic [15:0] topAddress;

//offset inside the areana 
logic [10:0] arenaLocalX;
logic [10:0] arenaLocalY;

//Tile coordinates in the grid
logic [3:0] tileX;
logic [3:0] tileY;

//offset inside the tile
logic [4:0] tileOffsetX;
logic [4:0] tileOffsetY;

logic [9:0] tileAddress;
logic [9:0] woodAddress;

//------------- Region / Tile Selection -----------

logic [1:0] selectedRegion;

//Each row has 16 tiles, each tile is 2 bits
logic [31:0] arenaRowData;

//Indicates the index of the MSB of the wanted tile
logic [4:0] arenaBitIndex;

//The stored value of the tile the watned tile which indicates its type
logic [1:0] currentTile;

//------------- Address / Region Calculation -----------

always_comb begin

	topAddress = 16'd0;

	//arena offset
	arenaLocalX = 11'd0;
	arenaLocalY = 11'd0;

	//coordinates of the tile
	tileX = 4'd0;
	tileY = 4'd0;

	//offset inside the tile
	tileOffsetX = 5'd0;
	tileOffsetY = 5'd0;

	tileAddress = 10'd0;
	woodAddress = 10'd0;

	selectedRegion = REGION_WOOD;

	if (insideTop) begin

		selectedRegion = REGION_TOP;

		topAddress =
			(pixelY * 640) +
			pixelX;

	end

	else if (insideArena) begin

		selectedRegion = REGION_ARENA;

		arenaLocalX = pixelX - ARENA_LEFT;
		arenaLocalY = pixelY - ARENA_TOP;

		// Wanted tile coordinates inside the arena
		tileX = arenaLocalX / TILE_SIZE;
		tileY = arenaLocalY / TILE_SIZE;

		// offset inside the wanted tile
		tileOffsetX = arenaLocalX - (tileX * TILE_SIZE);
		tileOffsetY = arenaLocalY - (tileY * TILE_SIZE);

		tileAddress =
			(tileOffsetY * TILE_SIZE) +
			tileOffsetX;

	end

	//Repeat the wood tile on the entire screen and later gets overwritten
	woodAddress =
		(pixelY[4:0] * 32) + pixelX[4:0];

end

//------------- Arena Tile Lookup -----------

always_comb begin

	//Store the row vector
	case (tileY)

		4'd0:  arenaRowData = ARENA_ROW_0;
		4'd1:  arenaRowData = ARENA_ROW_1;
		4'd2:  arenaRowData = ARENA_ROW_2;
		4'd3:  arenaRowData = ARENA_ROW_3;
		4'd4:  arenaRowData = ARENA_ROW_4;
		4'd5:  arenaRowData = ARENA_ROW_5;
		4'd6:  arenaRowData = ARENA_ROW_6;
		4'd7:  arenaRowData = ARENA_ROW_7;
		4'd8:  arenaRowData = ARENA_ROW_8;
		4'd9:  arenaRowData = ARENA_ROW_9;
		4'd10: arenaRowData = ARENA_ROW_10;
		4'd11: arenaRowData = ARENA_ROW_11;
		4'd12: arenaRowData = ARENA_ROW_12;
		4'd13: arenaRowData = ARENA_ROW_13;
		4'd14: arenaRowData = ARENA_ROW_14;
		4'd15: arenaRowData = ARENA_ROW_15;

		default: arenaRowData = ARENA_ROW_0;

	endcase

	// TileX = 0 is stored at bits [31:30]
	//So we use the inverted behavior (31 - ())
	arenaBitIndex = 5'd31 - (tileX * 2);

	//Stores the type value of the wanted tile
	currentTile = arenaRowData[arenaBitIndex -: 2];

end

//------------- ROM Outputs -----------

logic [7:0] topRGB;
logic [7:0] grassRGB;
logic [7:0] stoneRGB;
logic [7:0] rockRGB;
logic [7:0] woodRGB;

logic [7:0] selectedRGB;

//------------- Top HUD ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (16),
	.LPM_NUMWORDS           (56320),
	.LPM_FILE               ("RTL/mifs/top_background_8bit.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) top_background_rom (
	.address (topAddress),
	.inclock (clk),
	.q       (topRGB)
);

//------------- Grass Tile ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/grass_tile_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) grass_tile_rom (
	.address (tileAddress),
	.inclock (clk),
	.q       (grassRGB)
);

//------------- Stone Tile ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/stone_tile_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) stone_tile_rom (
	.address (tileAddress),
	.inclock (clk),
	.q       (stoneRGB)
);

//------------- Rock Tile ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/rock_tile_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) rock_tile_rom (
	.address (tileAddress),
	.inclock (clk),
	.q       (rockRGB)
);

//------------- Wood Tile ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (1024),
	.LPM_FILE               ("RTL/mifs/wood_tile_32.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) wood_tile_rom (
	.address (woodAddress),
	.inclock (clk),
	.q       (woodRGB)
);

//------------- Final Background Color Selection -----------

always_comb begin

	selectedRGB = woodRGB;

	case (selectedRegion)

		REGION_TOP: begin
			selectedRGB = topRGB;
		end

		REGION_ARENA: begin

			case (currentTile)

				TILE_GRASS:
					selectedRGB = grassRGB;

				TILE_STONE:
					selectedRGB = stoneRGB;

				TILE_ROCK:
					selectedRGB = rockRGB;

				default:
					selectedRGB = grassRGB;

			endcase

		end

	endcase

end

//------------- Outputs -----------

assign BG_RGB =
	selectedRGB;

assign borderDR =
	!insideArena;

assign obstacle_DR =
	insideArena && (currentTile == TILE_ROCK);

endmodule
