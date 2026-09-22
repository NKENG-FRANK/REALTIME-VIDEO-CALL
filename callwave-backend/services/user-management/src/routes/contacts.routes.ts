import { Router } from 'express';
import { requireAuth } from '../middlewares/auth.js';
import { getContacts, addContact, updateContact, deleteContact } from '../controllers/contacts.controller.js';

const router = Router();

router.use(requireAuth);

router.get('/', getContacts);
router.post('/', addContact);
router.patch('/:contactId', updateContact);
router.delete('/:contactId', deleteContact);

export default router;
