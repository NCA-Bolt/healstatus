local _, addon = ...;

addon.makeMacro = function(name, icon, value)
	local _name = GetMacroInfo(name);

	if (_name) then
		EditMacro(name, name, icon, value);
	else
		CreateMacro(name, icon, value, false);
	end
end

addon.initMacro = function()
	addon.makeMacro("HealInteract", "132163",
"/cast [");

	addon.makeMacro("Interact", "132163",
"#showtooltip\n/cast [mod:alt] Hammer of Justice\n/castsequence reset=20 Seal of Righteousness,Judgement\n/run AcceptTrade();SelectGossipAvailableQuest(1);SelectGossipActiveQuest(1);CompleteQuest();SelectGossipOption(1);AcceptQuest();GetQuestReward(1);");
	addon.makeMacro("Cast", "132163",
"#showtooltip\n/stopcasting [mod:alt]\n/cast [mod:ctrl,mod:shift]Redemption;[mod:shift,mod:alt]Holy Light;[mod:alt]Cleanse;[mod:shift]Flash of Light(Rank 1);[mod:ctrl]Flash of Light(Rank 4);Flash of Light");

	addon.makeMacro("Party", "132163", 
"/tar [mod:shift,mod:ctrl]focus;[mod:shift,mod:alt]party4;[mod:alt]party3;[mod:shift]party2;[mod:ctrl]party1;player");
	addon.makeMacro("Raid1", "132163", 
"/tar [mod:ctrl,mod:alt,mod:shift]raid8;[mod:ctrl,mod:alt]raid7; [mod:ctrl,mod:shift]raid6;[mod:shift,mod:alt]raid5;[mod:alt]raid4;[mod:shift]raid3;[mod:ctrl]raid2;raid1");
	addon.makeMacro("Raid2", "132163", 
"/tar [mod:ctrl,mod:alt,mod:shift]raid16;[mod:ctrl,mod:alt]raid15; [mod:ctrl,mod:shift]raid14;[mod:shift,mod:alt]raid13;[mod:alt]raid12;[mod:shift]raid11;[mod:ctrl]raid10;raid9");
	addon.makeMacro("Raid3", "132163", 
"/tar [mod:ctrl,mod:alt,mod:shift]raid24;[mod:ctrl,mod:alt]raid23; [mod:ctrl,mod:shift]raid22;[mod:shift,mod:alt]raid21;[mod:alt]raid20;[mod:shift]raid19;[mod:ctrl]raid18;raid17");
	addon.makeMacro("Raid4", "132163", 
"/tar [mod:ctrl,mod:alt,mod:shift]raid32;[mod:ctrl,mod:alt]raid31; [mod:ctrl,mod:shift]raid30;[mod:shift,mod:alt]raid29;[mod:alt]raid28;[mod:shift]raid27;[mod:ctrl]raid26;raid25");
	addon.makeMacro("Raid5", "132163", 
"/tar [mod:ctrl,mod:alt,mod:shift]raid40;[mod:ctrl,mod:alt]raid39; [mod:ctrl,mod:shift]raid38;[mod:shift,mod:alt]raid37;[mod:alt]raid36;[mod:shift]raid35;[mod:ctrl]raid34;raid33");

	addon.makeMacro("Modifier", "132163", 
"/run AcceptTrade();LightStatus.parseCommand(IsControlKeyDown(),IsAltKeyDown(),IsShiftKeyDown())");
	addon.makeMacro("Follow", "135946", 
"/follow " .. addon.followBean.targetName);
end