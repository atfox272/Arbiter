module arbiter_iwrr_1cycle_tb;    
    // Requester number
    localparam P_REQUESTER_NUM                                  = 3;
    // Weight value of each requester (RCM: requester_weight[0] = max_weight)
    localparam [0:(P_REQUESTER_NUM*32)-1]  P_REQUESTER_WEIGHT  = {32'd5, 32'd3, 32'd2};
    localparam P_WEIGHT_W          = $clog2(P_REQUESTER_WEIGHT[0*32+:32]);

    logic                          clk;
    logic                          rst_n;
    logic  [P_REQUESTER_NUM - 1:0] req_i;
    logic  [P_WEIGHT_W - 1:0]      num_grant_req_i;
    logic                          grant_ready_i;
    logic  [P_REQUESTER_NUM - 1:0] grant_valid_o;
       
    arbiter_iwrr_1cycle
    #(
        .P_REQUESTER_NUM(P_REQUESTER_NUM),
        .P_REQUESTER_WEIGHT(P_REQUESTER_WEIGHT)
    )uut(
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req_i),
        .num_grant_req_i(num_grant_req_i),
        .grant_ready_i(grant_ready_i),
        .grant_valid_o(grant_valid_o)
    );
    
    initial begin
        clk <= 0;
        rst_n <= 0;
        req_i <= 0;
        grant_ready_i <= 0;
        num_grant_req_i = 1;
        #9; rst_n <= 1;
    end
    
    initial begin
        forever #1 clk <= ~clk;
    end
    
    initial begin
        req_i <= {P_REQUESTER_NUM{1'b1}};
        grant_ready_i <= 1'b1;
        #100;
        req_i <= 0;
        req_i[0] <= 1'b1;
        grant_ready_i <= 1'b1;
        #100;
        req_i <= 0;
        req_i[0] <= 1'b1;
        req_i[1] <= 1'b1;
        #100;
        grant_ready_i <= 1'b0;
        #200; $finish;
    end
endmodule