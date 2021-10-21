
/*
Markov Chain Project
Name: Zhiyu Liang & Weiqi Peng

Please see below for user instrucitons. Default inputs are given.

*/
(


s.waitForBoot { // the way all your programs should be formatted unless they are interactive...

/*
A very cheap but lit piano
*/
SynthDef(\piano, { |out=0, freq=440, gate=1|
    var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.3, sustain: 0);
    DetectSilence.ar(son, 0.01, doneAction:2);
    Out.ar(out, son * 0.1);
}).add;

/*
Drum :)
*/
SynthDef(\hithat, {arg out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0;
	var snd = WhiteNoise.ar(amp);
	var env = Env.perc(att, rel).kr(doneAction: 2);
	snd = HPF.ar(snd * env, ffreq);
	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "Bruno Tucunduva Ruviaro",
	category: \drums,
	tags: [\percussion, \hihat]
)
).add;

// Define all the SynthDefs used
// We take all them here without mentioning otherwise: https://github.com/SCLOrkHub/SCLOrkSynths/blob/master/SynthDefs/drums/hihat1.scd



t = TempoClock.default; // the default clock
t.tempo = 100/60;

/*
This is the function to read one channel from a midi file.
Parameters:
	TODO
*/
~read_channel = {
	|file_name, chan_num, init_p, init_d, order_p = 3, order_d = 3, gen_num = 200,
		instrument = \piano, amp, start=0, end=100|
	~m = SimpleMIDIFile.read(file_name.resolveRelative);
	~n = ~m.generatePatternSeqs;

	~p = [];
	~d = [];
	~n[chan_num].slice((start..end), nil).do { |item, i| ~p = ~p.add(item[0]) };
    ~n[chan_num].slice((start..end), nil).do { |item, i| ~d = ~d.add(item[1]) };

	~mk = MarkovSetN.fill(100, Pseq(~p, inf).asStream, order_p);
	~mk.makeSeeds;
	~mkd = MarkovSetN.fill(100, Pseq(~d, inf).asStream, order_d);
	~mkd.makeSeeds;

	~x = ~mk.asStream;
	~x.postln;
	~x.next(init_p);
	~xd = ~mkd.asStream;
	~xd.postln;
	~xd.next(init_d);

	~z = Array.fill(gen_num, {~x.next});
	~zd = Array.fill(gen_num, {~xd.next});

	// currently the intrument is removed for the issue of memory explosion
	Pbind(/*\instrument, instrument, */\midinote, Pseq(~z, 1), \dur, Pseq(~zd,1), \amp, amp);

};

/*
Generate mulitple pieces based on markov chains trained on the midi file. A more randomized version is given as ~gen_pieces_random.
TODO:

*/
~gen_pieces = {
	|file_name, n_piece, chan_idx, gen_len=100|
	~m = SimpleMIDIFile.read(file_name.resolveRelative);
	~n = ~m.generatePatternSeqs;
	~sep1 = ~n[chan_idx[0]].shape[0]/n_piece.asInteger;
	~sep2 = ~n[chan_idx[1]].shape[0]/n_piece.asInteger;
	~sep3 = ~n[chan_idx[2]].shape[0]/n_piece.asInteger;
	~ppars = []; // The list of Ppars as output
	for(1, n_piece, {
		arg i;
		~pb1 = ~read_channel.(file_name, chan_idx[0], [75, 75, 77], [1.5], 3, 3, gen_len,\violin, 0.4, (i-1)*~sep1, i*~sep1);
		~pb2 = ~read_channel.(file_name, chan_idx[1], [39, 37], [2, 2], 3, 3, gen_len, \piano, 0.3, (i-1)*~sep2, i*~sep2);
		~pb3 = ~read_channel.(file_name, chan_idx[2], [69, 37], [1.5], 3, 3, gen_len, \piano, 0.2, (i-1)*~sep3, i*~sep3);

		~ppars = ~ppars.add(Ppar([~pb1, ~pb2, ~pb3], 1));
	});
	~ppars;
};

/*
Helper function: calculate the average of an array.
*/
~average = {
	| arr |
	var avg = 0;
	for(0, arr.size-1, {
		arg i;
		avg = avg + arr[i];
	});
	avg/arr.size;
};

/*
Everything is more randomized. Durations of three layers are adjusted so that they end simultaneously.
*/
~gen_pieces_random = {
	|file_name, n_piece, chan_idx, orders, gen_len=100|
	~m = SimpleMIDIFile.read(file_name.resolveRelative);
	~n = ~m.generatePatternSeqs;
	~sep1 = ~n[chan_idx[0]].shape[0]/n_piece.asInteger;
	~init_p1 = ~n[chan_idx[0]].slice(nil, (0)).choose();
	~init_d1 = ~n[chan_idx[0]].slice(nil, (1)).choose();
	~avgd1 = ~average.(~n[chan_idx[0]].slice(nil, (1)));
	~sep2 = ~n[chan_idx[1]].shape[0]/n_piece.asInteger;
	~init_p2 = ~n[chan_idx[1]].slice(nil, (0)).choose();
	~init_d2 = ~n[chan_idx[1]].slice(nil, (1)).choose();
	~avgd2 = ~average.(~n[chan_idx[1]].slice(nil, (1)));
	~sep3 = ~n[chan_idx[2]].shape[0]/n_piece.asInteger;
	~init_p3 = ~n[chan_idx[2]].slice(nil, (0)).choose();
	~init_d3 = ~n[chan_idx[2]].slice(nil, (1)).choose();
	~avgd3 = ~average.(~n[chan_idx[2]].slice(nil, (1)));
	~ppars = []; // The list of Ppars as output,
	for(1, n_piece, {
		arg i;
	~pb1 = ~read_channel.(file_name, chan_idx[0], [~init_p1], [~init_d1], orders.choose(), orders.choose(), gen_len, \piano, 0.4, (i-1)*~sep1, i*~sep1-1);
	~pb2 = ~read_channel.(file_name, chan_idx[1], [~init_p2], [~init_d2], orders.choose(), orders.choose(), (gen_len*~avgd1/~avgd2).asInteger, \piano, 0.2, (i-1)*~sep2, i*~sep2-1);
	~pb3 = ~read_channel.(file_name, chan_idx[2], [~init_p3], [~init_d3], orders.choose(), orders.choose(), (gen_len*~avgd1/~avgd3).asInteger, \hithat, 0.3, (i-1)*~sep3, i*~sep3-1);

	~ppars = ~ppars.add(Ppar([~pb1, ~pb2, ~pb3], 1));
	});
	~ppars;
};

~num_pieces = 3 ; // by the end move this to the front
~len_piece = 30;  // how long is one piece?

~playSec = {
	|section|

    // choose randomly from pieces but never return twice an item
	Pxrand(section).play;

};

// we then put all them together--say we have multiple sections
// each section contains several pieces

~secA = ~gen_pieces_random.("mid/flower_dance.mid", ~num_pieces, [2,3,6], [1,2,3], ~len_piece);
~secB = ~gen_pieces_random.("mid/spectre.mid", ~num_pieces, [1,2,3], [1,2,3], ~len_piece);

	// ~playSec.([~secA, ~secB]); //this doesn' work
~playSec.(~secB);

// TODO: figure out a way to play the sections in sequence

// USE THE BELOW SECTION FOR TESTING - DELETE THEM FOR SUBMISSION
	// ~a = ~gen_pieces_random.("mid/flower_dance.mid", 3, [2,3,6], [1,2,3], 100);
	// ~a = ~gen_pieces.("mid/flower_dance.mid", 3, [2,3,6], 50);
	//
	// ~pb1 = ~read_channel.("mid/flower_dance.mid", 5, [90], [1.5], 3, 3, 100, \None, 0.4, 0, 1200);
	// ~pb2 = ~read_channel.("mid/spectre.mid", 2, [39, 37], [2, 2], 3, 3, 100, \, 0.3, 0, 100);
	// ~pb3 = ~read_channel.("mid/spectre.mid", 3, [69, 37], [1.5], 3, 3, 100, \piano, 0.2, 0, 200);
	// Ppar([~pb1, ~pb2, ~pb3], 1);
	//
	// // ~pb1.play;
	//
	// ~a[0].play;
	//
	//
	// ~n[1].postln;
	// ~m = SimpleMIDIFile.read("mid/flower_dance.mid".resolveRelative);
	// ~n = ~m.generatePatternSeqs;
	// ~n[6].slice(nil, (1));

}

)
