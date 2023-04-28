module ModTop (
    input  reg [4:0][4:0] prev,
    output reg [4:0][4:0] next
);
  Evalution #(5) evalution (
      .prev(prev),
      .next(next)
  );

endmodule
