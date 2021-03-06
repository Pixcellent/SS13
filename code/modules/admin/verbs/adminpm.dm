//allows right clicking mobs to send an admin PM to their client, forwards the selected mob's client to cmd_admin_pm
/client/proc/cmd_admin_pm_context(mob/M as mob in mob_list)
	set category = null
	set name = "Admin PM Mob"
	if(!holder)
		src << "<font color='red'>Error: Admin-PM-Context: Only administrators may use this command.</font>"
		return
	if( !ismob(M) || !M.client )	return
	cmd_admin_pm(M.client,null)
	feedback_add_details("admin_verb","APMM") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!

//shows a list of clients we could send PMs to, then forwards our choice to cmd_admin_pm
/client/proc/cmd_admin_pm_panel()
	set category = "Admin"
	set name = "Admin PM"
	if(!holder)
		src << "<font color='red'>Error: Admin-PM-Panel: Only administrators may use this command.</font>"
		return
	var/list/client/targets[0]
	for(var/client/T)
		if(T.mob)
			if(istype(T.mob, /mob/new_player))
				targets["(New Player) - [T]"] = T
			else if(istype(T.mob, /mob/dead/observer))
				targets["[T.mob.name](Ghost) - [T]"] = T
			else
				targets["[T.mob.real_name](as [T.mob.name]) - [T]"] = T
		else
			targets["(No Mob) - [T]"] = T
	var/list/sorted = sortList(targets)
	var/target = input(src,"To whom shall we send a message?","Admin PM",null) in sorted|null
	cmd_admin_pm(targets[target],null)
	feedback_add_details("admin_verb","APM") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!


//takes input from cmd_admin_pm_context, cmd_admin_pm_panel or /client/Topic and sends them a PM.
//Fetching a message if needed. src is the sender and C is the target client
/client/proc/cmd_admin_pm(whom, msg, var/admin_conversation)
	if(prefs.muted & MUTE_ADMINHELP)
		src << "<font color='red'>Error: Admin-PM: You are unable to use admin PM-s (muted).</font>"
		return

	var/datum/admin_conversation/convo
	if(admin_conversation)
		convo = locate(admin_conversation)

	var/client/C
	if(istext(whom))
		C = directory[whom]
	else if(istype(whom,/client))
		C = whom
	if(!C)
		if(holder)
			src << "<font color='red'>Error: Admin-PM: Client not found.</font>"
			src.send_text_to_tab("<font color='red'>Error: Admin-PM: Client not found.</font>", "ahelp")
		else		adminhelp(msg)	//admin we are replying to left. adminhelp instead
		return

	//get message text, limit it's length.and clean/escape html
	if(!msg)
		msg = input(src,"Message:", "Private message to [key_name(C, 0, 0)]") as text|null

		if(!msg)	return
		if(!C)
			if(holder)
				src << "<font color='red'>Error: Admin-PM: Client not found.</font>"
				src.send_text_to_tab("<font color='red'>Error: Admin-PM: Client not found.</font>", "ahelp")
			else		adminhelp(msg)	//admin we are replying to has vanished, adminhelp instead
			return

	if (src.handle_spam_prevention(msg,MUTE_ADMINHELP))
		return

	//clean the message if it's not sent by a high-rank admin
	if(!check_rights(R_SERVER|R_DEBUG,0))
		msg = sanitize(copytext(msg,1,MAX_MESSAGE_LEN))
		if(!msg)	return

	if(C.holder)
		var/shown_to_receiver = "<font color='red'>Reply PM from-<b>[key_name(src, C, 1, admin_conversation)]</b>: [msg]</font>"
		var/shown_to_sender = ""

		if(convo)
			convo.LogReply(src.ckey, C.ckey, msg)

		if(holder)	//both are admins
			if(convo)
				if(convo.IsAdminParticipating())
					convo.participants += list("add_admin", src.ckey)
				else
					convo.SetAdminParticipant(src.ckey)
			if(admin_conversation)
				shown_to_sender = "<font color='blue'>Admin PM to-<b>[key_name(C, src, 1, admin_conversation)]</b>: [msg]</font>"
			else
				shown_to_sender = "<font color='blue'>Admin PM to-<b>[key_name(C, src, 1)]</b>: [msg]</font>"
		else		//recipient is an admin but sender is not
			shown_to_sender = "<font color='blue'>PM to-<b>Admins</b>: [msg]</font>"
		if(C.admintoggles)
			C << shown_to_receiver
		C.send_text_to_tab(shown_to_receiver, "ahelp")
		if(src.admintoggles)
			src << shown_to_sender
		src.send_text_to_tab(shown_to_sender, "ahelp")

		//play the recieving admin the adminhelp sound (if they have them enabled)
		if(C.prefs.toggles & SOUND_ADMINHELP)
			C << 'sound/effects/adminhelp.ogg'

	else
		if(holder)	//sender is an admin but recipient is not. Do BIG RED TEXT
			var/shown_to_receiver = {"
			<font color='red' size='4'><b>-- Administrator private message --</b></font>
			<BR><font color='red'>Admin PM from-<b>[key_name(src, C, 0, admin_conversation)]</b>: [msg]</font>
			<BR><font color='red'><i>Click on the administrator's name to reply.</i></font>
			"}

			var/shown_to_sender = "<font color='blue'>Admin PM to-<b>[key_name(C, src, 1, admin_conversation)]</b>: [msg]</font>"

			if(convo)
				convo.LogReply(src.ckey, C.ckey, msg)
				if(convo.IsAdminParticipating())
					convo.participants += list("add_admin", src.ckey)
				else
					convo.SetAdminParticipant(src.ckey)

			C << shown_to_receiver
			C.send_text_to_tab(shown_to_receiver, "ahelp")
			C.send_text_to_tab(shown_to_receiver, "ic")
			C.send_text_to_tab(shown_to_receiver, "ooc")
			if(src.admintoggles)
				src << shown_to_sender
			src.send_text_to_tab(shown_to_sender, "ahelp")

			//always play non-admin recipients the adminhelp sound
			C << 'sound/effects/adminhelp.ogg'

			//AdminPM popup for ApocStation and anybody else who wants to use it. Set it with POPUP_ADMIN_PM in config.txt ~Carn
			if(config.popup_admin_pm)
				spawn()	//so we don't hold the caller proc up
					var/sender = src
					var/sendername = key
					var/reply = input(C, msg,"Admin PM from-[sendername]", "") as text|null		//show message and await a reply
					if(C && reply)
						if(sender)
							C.cmd_admin_pm(sender,reply)										//sender is still about, let's reply to them
						else
							adminhelp(reply)													//sender has left, adminhelp instead
					return

		else		//neither are admins
			src << "<font color='red'>Error: Admin-PM: Non-admin to non-admin PM communication is forbidden.</font>"
			return

	log_admin("PM: [key_name(src)]->[key_name(C)]: [msg]")

	//we don't use message_admins here because the sender/receiver might get it too
	for(var/client/X in admins)
		if(X.key!=key && X.key!=C.key)	//check client/X is an admin and isn't the sender or recipient
			var/to_other_admins = "<B><font color='blue'>PM: [key_name(src, X, 0)]-&gt;[key_name(C, X, 0)]:</B> \blue [msg]</font>" //inform X
			if(X.admintoggles)
				X << to_other_admins
			spawn(1)
				X.send_text_to_tab(to_other_admins, "ahelp")
