implement RetryMount;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "../../../logger/module/logger.m";
	logger: Logger;
	log, ERR, WARN, NOTICE, INFO, DEBUG: import logger;
include "sh.m";

RetryMount: module
{
	init: fn(nil: ref Draw->Context, argv: list of string);
};

MountArgs: adt
{
	addr: string;
	_rargs1, _args2: list of string;

	new: fn(args: list of string): ref MountArgs;
	get: fn(this: self ref MountArgs): list of string;
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	logger = load Logger Logger->PATH;
	if(logger == nil)
		raise sprint("load: Logger: %r");
	logger->init();
	arg = checkload(load Arg Arg->PATH, "Arg");
	arg->init(argv);
	logger->progname(arg->progname());

	sync := chan of int;
	spawn retrymount(tl argv, sync);
	<-sync;
}

retrymount(args: list of string, sync: chan of int)
{
	sync <-= sys->pctl(0, nil);
	unmounted := 0;
	for(;;){
		{
			unmounted = mount(args);
		} exception {
			* => ;
		}
		if(unmounted){
			log(INFO, "unmounted, exiting");
			break;
		}
		sys->sleep(1000);
		s := "retrying mount";
		for(l := args; l != nil; l = tl l)
			s += " " + hd l;
		log(WARN, s);
	}
}

mount(args: list of string): int
{
	mnt := array[2] of ref Sys->FD;
	if(sys->pipe(mnt) == -1)
		fail(sprint("pipe: %r"));

	m := MountArgs.new(args);
	net := connect(m.addr);
	m.addr = "/fd/" + string mnt[1].fd;
	argv := m.get();

	pidc := chan of int;
	donec := chan of int;
	spawn proxy(net, mnt[0], pidc, donec, 0);
	spawn proxy(mnt[0], net, pidc, donec, 1);
	(pid1, pid2) := (<-pidc, <-pidc);

	unmounted := 0;
	{
		mount := checkload(load Command "/dis/mount.dis", "/dis/mount.dis");
		mount->init(nil, argv);
		mnt[1] = nil;
		unmounted = <-donec;
	} exception { * => ; }

	pidctl(pid1, "kill");
	pidctl(pid2, "kill");
	return unmounted;
}

connect(addr: string): ref Sys->FD
{
	(ok, net) := sys->dial(addr, nil);
	if(ok == -1)
		fail(sprint("dial: %r"));
	if(sys->fprint(net.cfd, "%s", "keepalive") < 0)
		fail(sprint("activating keepalive: %r"));
	return net.dfd;
}

proxy(r, w: ref Sys->FD, pidc, donec: chan of int, handle_eof: int)
{
	pidc <-= sys->pctl(0, nil);
	buf := array[Sys->ATOMICIO] of byte;
	n : int;
	for(;;){
		n = sys->read(r, buf, len buf);
		if(n <= 0)
			break;
		if(sys->write(w, buf, n) != n)
			break;
	}
	donec <-= (handle_eof && n == 0);
}

MountArgs.new(args: list of string): ref MountArgs
{
	a := checkload(load Arg Arg->PATH, "Arg");
	a->init("mount" :: args);
	a->setusage(a->progname() + " [-a|-b] [-coA9] [-C cryptoalg] [-k keyfile] [-q] net!addr mountpoint [spec]");
	rargs1 := a->progname() :: nil;
	while((o := a->opt()) != 0){
		case o {
		'v' =>
			logger->verbose++;
			rargs1 = sprint("-%c", o) :: rargs1;
		'a' or 'b' or 'c' or 'A' or '9' or 'o' or 'P' or 'S' or 'q' =>
			rargs1 = sprint("-%c", o) :: rargs1;
		'C' or 'k' or
		'f' =>
			rargs1 = a->earg() :: sprint("-%c", o) :: rargs1;
		*   =>
			a->usage();
		}
	}
	args2 := a->argv();
	if(len args2 < 2 || len args2 > 3)
		a->usage();
	addr := hd args2;
	args2 = tl args2;

	return ref MountArgs(addr, rargs1, args2);
}

MountArgs.get(this: self ref MountArgs): list of string
{
	argv := this.addr :: this._args2;
	for(l := this._rargs1; l != nil; l = tl l)
		argv = hd l :: argv;
	return argv;
}

###

fail(s: string)
{
	log(ERR, s);
	raise "fail:"+s;
}

checkload[T](x: T, s: string): T
{
	if(x == nil)
		fail(sprint("load: %s: %r", s));
	return x;
}

pidctl(pid: int, s: string): int
{
	f := sprint("#p/%d/ctl", pid);
	fd := sys->open(f, Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "%s", s) < 0){
		log(DEBUG, sprint("pidctl(%d, %s): %r", pid, s));
		return 0;
	}
	return 1;
}


