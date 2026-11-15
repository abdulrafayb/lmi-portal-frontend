const escape = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export function quoteEmail(values, reference, date) {
  const rows = [
    ["Full name", values.name],
    ["Company", values.company || "Not provided"],
    ["Email address", values.email],
    ["Phone number", values.phone],
    ["Transportation requirement", values.service],
    ["Origin", values.origin],
    ["Destination", values.destination],
  ];
  const submitted =
    new Intl.DateTimeFormat("en-GB", {
      dateStyle: "long",
      timeStyle: "short",
      timeZone: "Asia/Karachi",
    }).format(date) + " PKT";
  const text = [
    "New transportation quote request",
    ...rows.map(([label, value]) => `${label}: ${value}`),
    "",
    "Requirement details:",
    values.details,
    "",
    `Submitted: ${submitted}`,
    `Reference: ${reference}`,
    "Reply to this email to contact the customer.",
  ].join("\n");
  const html = `<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>New quote request</title></head><body style="margin:0;background:#f6f4ef;color:#222120;font-family:Arial,Helvetica,sans-serif"><div style="display:none;max-height:0;overflow:hidden">New enquiry from ${escape(values.name)} — ${escape(values.service)}</div><table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td style="padding:32px 16px"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;margin:auto;background:#fff;border:1px solid #e9e5df;border-top:5px solid #c22735;border-radius:10px"><tr><td style="padding:28px 28px 20px"><p style="margin:0 0 8px;color:#c22735;font-size:12px;font-weight:bold;letter-spacing:1px">LOGISTICS MANAGEMENT INTERNATIONAL</p><h1 style="margin:0 0 10px;font-size:26px">New transportation enquiry</h1><p style="margin:0;color:#66615c;line-height:1.6">A visitor has requested a quote through the LMI website.</p></td></tr><tr><td style="padding:0 28px"><table width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">${rows.map(([label, value]) => `<tr><th scope="row" align="left" valign="top" style="width:38%;padding:13px 10px 13px 0;border-bottom:1px solid #e9e5df;font-size:13px;color:#66615c;font-weight:normal">${escape(label)}</th><td style="padding:13px 0;border-bottom:1px solid #e9e5df;font-size:14px;line-height:1.5;overflow-wrap:anywhere">${escape(value)}</td></tr>`).join("")}</table><h2 style="font-size:16px;margin:24px 0 12px">Requirement details</h2><div style="padding:18px;background:#f6f4ef;border-radius:6px;font-size:14px;line-height:1.7;white-space:pre-wrap;overflow-wrap:anywhere">${escape(values.details)}</div><p style="margin:24px 0"><a href="mailto:${escape(encodeURIComponent(values.email))}" style="display:inline-block;background:#c22735;color:#fff;padding:14px 20px;border-radius:4px;text-decoration:none;font-size:14px;font-weight:bold">Reply to ${escape(values.name)}</a></p><p style="font-size:12px;color:#66615c;line-height:1.7">Submitted: ${escape(submitted)}<br>Reference: ${escape(reference)}</p></td></tr><tr><td style="padding:18px 28px;background:#f6f4ef;font-size:12px;color:#66615c;line-height:1.6">This message was submitted through the public LMI quote form. Customer details are provided by the sender. Use Reply to contact the customer.</td></tr></table></td></tr></table></body></html>`;
  return {
    html,
    text,
    subject: `New Quote Request — ${values.service} — ${values.name}`,
  };
}
