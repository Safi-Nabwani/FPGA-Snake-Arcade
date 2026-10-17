// Generated from supplied ZIP artwork only. Right-local coordinates; no HUD coverage.
localparam int MENU_ROM_DEPTH=104476;
localparam int MENU_ADDRESS_WIDTH=17;
always_comb begin
    menuAddress={{3{1'b0}},menuBackgroundAddress};
    // title
    if(menuVisible && menuX>=9'd120 && menuX<9'd384 && menuY>=9'd58 && menuY<9'd166) begin
        menuAddress=17'd14880 + (({{8{1'b0}}, menuY} - 17'd58) << 3) + (({{8{1'b0}}, menuY} - 17'd58) << 8) + {{8{1'b0}},menuX} - 17'd120;
    end
    // controls_heading
    if(menuVisible && menuX>=9'd34 && menuX<9'd150 && menuY>=9'd204 && menuY<9'd229) begin
        menuAddress=17'd43392 + (({{8{1'b0}}, menuY} - 17'd204) << 2) + (({{8{1'b0}}, menuY} - 17'd204) << 4) + (({{8{1'b0}}, menuY} - 17'd204) << 5) + (({{8{1'b0}}, menuY} - 17'd204) << 6) + {{8{1'b0}},menuX} - 17'd34;
    end
    // keys
    if(menuVisible && menuX>=9'd37 && menuX<9'd142 && menuY>=9'd238 && menuY<9'd336) begin
        menuAddress=17'd46292 + ({{8{1'b0}}, menuY} - 17'd238) + (({{8{1'b0}}, menuY} - 17'd238) << 3) + (({{8{1'b0}}, menuY} - 17'd238) << 5) + (({{8{1'b0}}, menuY} - 17'd238) << 6) + {{8{1'b0}},menuX} - 17'd37;
    end
    // control_caption
    if(menuVisible && menuX>=9'd20 && menuX<9'd160 && menuY>=9'd338 && menuY<9'd374) begin
        menuAddress=17'd56582 + (({{8{1'b0}}, menuY} - 17'd338) << 2) + (({{8{1'b0}}, menuY} - 17'd338) << 3) + (({{8{1'b0}}, menuY} - 17'd338) << 7) + {{8{1'b0}},menuX} - 17'd20;
    end
    // relics_heading
    if(menuVisible && menuX>=9'd194 && menuX<9'd314 && menuY>=9'd204 && menuY<9'd229) begin
        menuAddress=17'd61622 + (({{8{1'b0}}, menuY} - 17'd204) << 3) + (({{8{1'b0}}, menuY} - 17'd204) << 4) + (({{8{1'b0}}, menuY} - 17'd204) << 5) + (({{8{1'b0}}, menuY} - 17'd204) << 6) + {{8{1'b0}},menuX} - 17'd194;
    end
    // ruby
    if(menuVisible && menuX>=9'd196 && menuX<9'd330 && menuY>=9'd236 && menuY<9'd279) begin
        menuAddress=17'd64622 + (({{8{1'b0}}, menuY} - 17'd236) << 1) + (({{8{1'b0}}, menuY} - 17'd236) << 2) + (({{8{1'b0}}, menuY} - 17'd236) << 7) + {{8{1'b0}},menuX} - 17'd196;
    end
    // sapphire
    if(menuVisible && menuX>=9'd196 && menuX<9'd330 && menuY>=9'd281 && menuY<9'd323) begin
        menuAddress=17'd70384 + (({{8{1'b0}}, menuY} - 17'd281) << 1) + (({{8{1'b0}}, menuY} - 17'd281) << 2) + (({{8{1'b0}}, menuY} - 17'd281) << 7) + {{8{1'b0}},menuX} - 17'd196;
    end
    // cursed
    if(menuVisible && menuX>=9'd190 && menuX<9'd330 && menuY>=9'd328 && menuY<9'd372) begin
        menuAddress=17'd76012 + (({{8{1'b0}}, menuY} - 17'd328) << 2) + (({{8{1'b0}}, menuY} - 17'd328) << 3) + (({{8{1'b0}}, menuY} - 17'd328) << 7) + {{8{1'b0}},menuX} - 17'd190;
    end
    // goal_heading
    if(menuVisible && menuX>=9'd389 && menuX<9'd465 && menuY>=9'd204 && menuY<9'd229) begin
        menuAddress=17'd82172 + (({{8{1'b0}}, menuY} - 17'd204) << 2) + (({{8{1'b0}}, menuY} - 17'd204) << 3) + (({{8{1'b0}}, menuY} - 17'd204) << 6) + {{8{1'b0}},menuX} - 17'd389;
    end
    // goal
    if(menuVisible && menuX>=9'd379 && menuX<9'd473 && menuY>=9'd242 && menuY<9'd352) begin
        menuAddress=17'd84072 + (({{8{1'b0}}, menuY} - 17'd242) << 1) + (({{8{1'b0}}, menuY} - 17'd242) << 2) + (({{8{1'b0}}, menuY} - 17'd242) << 3) + (({{8{1'b0}}, menuY} - 17'd242) << 4) + (({{8{1'b0}}, menuY} - 17'd242) << 6) + {{8{1'b0}},menuX} - 17'd379;
    end
    // start
    if(menuVisible && menuX>=9'd100 && menuX<9'd396 && menuY>=9'd414 && menuY<9'd448) begin
        menuAddress=17'd94412 + (({{8{1'b0}}, menuY} - 17'd414) << 3) + (({{8{1'b0}}, menuY} - 17'd414) << 5) + (({{8{1'b0}}, menuY} - 17'd414) << 8) + {{8{1'b0}},menuX} - 17'd100;
    end
end
