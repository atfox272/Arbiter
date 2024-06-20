module arbiter_iwrr_tb;    
    // Requester number
    localparam P_REQUESTER_NUM                                  = 3;
    // Weight value of each requester (RCM: requester_weight[0] = max_weight)
    localparam int P_REQUESTER_WEIGHT   [0:P_REQUESTER_NUM-1]   = {5, 3, 2};

    reg                             clk;
    reg                             rst_n;
    reg     [P_REQUESTER_NUM - 1:0] request;
    reg                             grant_ready;
       
    // Output declaration
    wire    [P_REQUESTER_NUM - 1:0] grant_valid;
    
    arbiter_iwrr 
    #(
        .P_REQUESTER_NUM(P_REQUESTER_NUM),
        .P_REQUESTER_WEIGHT(P_REQUESTER_WEIGHT)
    )uut(
        .clk(clk),
        .rst_n(rst_n),
        .request(request),
        .grant_ready(grant_ready),
        .grant_valid(grant_valid)
    );
    
    initial begin
        clk <= 0;
        rst_n <= 0;
        request <= 0;
        grant_ready <= 0;
        #9; rst_n <= 1;
    end
    
    initial begin
        forever #1 clk <= ~clk;
    end
    
    initial begin
        request <= {P_REQUESTER_NUM{1'b1}};
        grant_ready <= 1'b1;
        #100;
        request <= {1'b1, 1'b0, 1'b0};
        grant_ready <= 1'b1;
        #200; $finish;
    end
endmodule
