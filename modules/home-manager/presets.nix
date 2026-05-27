{
  providers = {
    startmail = {
      imapHost = "imap.startmail.com";
      imapPort = 993;
      smtpHost = "smtp.startmail.com";
      smtpPort = 465;
    };
  };

  folders = {
    startmail = {
      archiveFolder = "Archive";
      draftsFolder = "Drafts";
      sentFolder = "Sent Messages";
      trashFolder = "Deleted Messages";
      spamFolder = "Junk";
    };

    generic = {
      archiveFolder = "Archive";
      draftsFolder = "Drafts";
      sentFolder = "Sent";
      trashFolder = "Trash";
      spamFolder = "Junk";
    };
  };
}
