export function formatMatricule(matricule: string): string {
  // Convert any alphabetic character to uppercase
  return matricule.replace(/[a-zA-Z]/g, (match) => match.toUpperCase());
}

export function validateMatricule(matricule: string): boolean {
  if (!matricule || matricule.length !== 8) {
    return false;
  }
  // Exactly 8 characters with 1 letter either at start or end, and 7 digits
  return /^(?:[A-Za-z]\d{7}|\d{7}[A-Za-z])$/.test(matricule.trim());
}
