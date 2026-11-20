import { StartupGate } from './components/loaders/StartupGate';
import MentorOnboarding from './pages/MentorOnboarding';
import MentorApplication from './pages/MentorApplication';
import MentorGuidelines from './pages/MentorGuidelines';
import AdminMentorApplications from './pages/AdminMentorApplications';
import PublicEvents from './pages/PublicEvents';
import PublicEventDetails from './pages/PublicEventDetails';
import HostEvent from './pages/HostEvent';
import PartnerWithUs from './pages/PartnerWithUs';
import PublicLearningResources from './pages/PublicLearningResources';
import PublicLearningResourceDetails from './pages/PublicLearningResourceDetails';
import PublicCatalog from './pages/PublicCatalog';
import PublicPrograms from './pages/PublicPrograms';
import PublicProgramDetails from './pages/PublicProgramDetails';
import AdminInquiries from './pages/AdminInquiries';
import AdminIntegrations from './pages/AdminIntegrations';
import AdminReports from './pages/AdminReports';
import AdminGoals from './pages/AdminGoals';
import AdminMessages from './pages/AdminMessages';
import AdminAchievements from './pages/AdminAchievements';
import AdminAchievementDetails from './pages/AdminAchievementDetails';
import AdminGoalDetails from './pages/AdminGoalDetails';
import AdminEventDetails from './pages/AdminEventDetails';
import AdminEvents from './pages/AdminEvents';
import LearnerResource from './pages/LearnerResource';
import AdminResourceDetails from './pages/AdminResourceDetails';
import AdminResources from './pages/AdminResources';
import AdminSessionDetails from './pages/AdminSessionDetails';
import AdminSessions from './pages/AdminSessions';
import AdminProgramDetails from './pages/AdminProgramDetails';
import AdminPrograms from "./pages/AdminPrograms";
import AdminMenteeDetails from "./pages/AdminMenteeDetails";
import AdminMentees from "./pages/AdminMentees";
import { Toaster } from '@/components/ui/sonner';
import { Toaster as RadixToaster } from '@/components/ui/toaster';
import { TooltipProvider } from '@/components/ui/tooltip';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { HelmetProvider } from 'react-helmet-async';

// Pages
import Index from './pages/Index';
import Login from './pages/Login';
import Register from './pages/Register';
import Services from './pages/Services';
import Dashboard from './pages/Dashboard';
import MenteeDashboard from './pages/MenteeDashboard';
import MyMentorship from './pages/MyMentorship';
import LearningArea from './pages/LearningArea';
import MyGoals from './pages/MyGoals';
import MyActivities from './pages/MyActivities';
import MyAchievements from './pages/MyAchievements';
import Events from './pages/Events';
import MentorSelfProfile from './pages/MentorSelfProfile';
import Bookings from './pages/Bookings';
import Messages from './pages/Messages';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import CreateService from './pages/CreateService';
import LeaveReview from './pages/LeaveReview';
import NotFound from './pages/NotFound';
import FAQ from './pages/FAQ';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsOfService from './pages/TermsOfService';
import HelpCenter from './pages/HelpCenter';
import Contact from './pages/Contact';
import Blog from './pages/Blog';
import Careers from './pages/Careers';
import AboutUs from './pages/AboutUs';
import HowItWorks from './pages/HowItWorks';
import MentorProfile from './pages/MentorProfile';
import EditProfile from './pages/EditProfile';
import Notifications from './pages/Notifications';
import AdminDashboard from './pages/AdminDashboard';
import AdminCatalog from './pages/AdminCatalog';
import SystemSettings from './pages/SystemSettings';
import UsersAndRoles from './pages/UsersAndRoles';
import { PlatformProvider, PlatformBoundary } from './lib/platform-context';

// Context Providers
import { AuthProvider } from './lib/auth-context';
import { ServicesProvider } from './lib/services-context';
import { MessagingProvider } from './lib/messaging-context';
import CategoryDetail from './pages/CategoryDetail';
import Categories from './pages/Categories';
import ServiceDetailPage from './pages/ServiceDetail';
import { RoleProvider } from './lib/role-context';
import { UsersProvider } from './lib/users-context';

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <HelmetProvider>
      <TooltipProvider>
        <AuthProvider>
          <RoleProvider>
            <UsersProvider>
              <ServicesProvider>
                <MessagingProvider>
                    <Toaster />
                    <RadixToaster />
                    <BrowserRouter><PlatformProvider><StartupGate><PlatformBoundary>
                      <Routes>
                      {/* Public routes */}
                      <Route path="/become-a-mentor" element={<MentorOnboarding />} />
                      <Route path="/mentor-onboarding" element={<MentorOnboarding />} />
                      <Route path="/mentor/application" element={<MentorApplication />} />
                      <Route path="/mentor-guidelines" element={<MentorGuidelines />} />
                      <Route path="/admin/mentor-applications" element={<AdminMentorApplications />} />
                      <Route path="/" element={<Index />} />
                      <Route path="/programs" element={<PublicPrograms />} />
                      <Route path="/programs/:id" element={<PublicProgramDetails />} />
                      <Route path="/learn" element={<PublicLearningResources />} />
                      <Route path="/learn/:id" element={<PublicLearningResourceDetails />} />
                      <Route path="/learn/courses" element={<PublicCatalog key="learning" kind="learning" />} />
                      <Route path="/community-events" element={<PublicEvents />} />
                      <Route path="/community-events/:id" element={<PublicEventDetails />} />
                      <Route path="/partner-with-us" element={<PartnerWithUs />} />
                      <Route path="/host-an-event" element={<HostEvent />} />
                      <Route path="/admin/inquiries" element={<AdminInquiries />} />
                      <Route path="/login" element={<Login />} />
                      <Route path="/register" element={<Register />} />
                      <Route path="/services" element={<Services />} />
                      <Route path="/services/:id" element={<ServiceDetailPage />} />
                      <Route path="/categories" element={<Categories />} />
                      <Route path="/categories/:slug" element={<CategoryDetail />} />
                      <Route path="/mentors/:mentorId" element={<MentorProfile />} />
                      
                      {/* Information pages */}
                      <Route path="/faq" element={<FAQ />} />
                      <Route path="/privacy-policy" element={<PrivacyPolicy />} />
                      <Route path="/terms-of-service" element={<TermsOfService />} />
                      <Route path="/help" element={<HelpCenter />} />
                      <Route path="/contact" element={<Contact />} />
                      <Route path="/blog" element={<Blog />} />
                      <Route path="/careers" element={<Careers />} />
                      <Route path="/about" element={<AboutUs />} />
                      <Route path="/how-it-works" element={<HowItWorks />} />
                      
                      {/* Auth required routes */}
                      <Route path="/dashboard" element={<Dashboard />} />
                      <Route path="/events" element={<Events />} />
                      <Route path="/mentee/events" element={<Events />} />
                      <Route path="/my-achievements" element={<MyAchievements />} />
                      <Route path="/mentee/achievements" element={<MyAchievements />} />
                      <Route path="/my-activities" element={<MyActivities />} />
                      <Route path="/mentee/activities" element={<MyActivities />} />
                      <Route path="/my-goals" element={<MyGoals />} />
                      <Route path="/mentee/goals" element={<MyGoals />} />
                      <Route path="/learning/resources/:id" element={<LearnerResource />} />
                      <Route path="/learning-area" element={<LearningArea />} />
                      <Route path="/mentee/learning" element={<LearningArea />} />
                      <Route path="/mentee/dashboard" element={<MenteeDashboard />} />
                      <Route path="/mentor/mentorship" element={<MyMentorship />} />
                      <Route path="/mentor/profile" element={<MentorSelfProfile />} />
                      <Route path="/bookings" element={<Bookings />} />
                      <Route path="/services/create" element={<CreateService />} />
                      <Route path="/reviews/:bookingId" element={<LeaveReview />} />
                      <Route path="/messages" element={<Messages />} />
                      <Route path="/messages/:id" element={<Messages />} />
                      <Route path="/profile" element={<Profile />} />
                      <Route path="/profile/:id" element={<Profile />} />
                      <Route path="/edit-profile" element={<EditProfile />} />
                      <Route path="/settings" element={<Settings />} />
                      <Route path="/notifications" element={<Notifications />} />
                      <Route path="/admin/integrations" element={<AdminIntegrations />} />
                      <Route path="/admin/reports" element={<AdminReports />} />
                      <Route path="/admin" element={<AdminDashboard />} />
                      <Route path="/admin/categories" element={<AdminCatalog />} />
                      <Route path="/admin/mentees/:id" element={<AdminMenteeDetails />} />
                      <Route path="/admin/resources/:id" element={<AdminResourceDetails />} />
                      <Route path="/admin/messages" element={<AdminMessages />} />
                      <Route path="/admin/messages/:id" element={<AdminMessages />} />
                      <Route path="/admin/achievements" element={<AdminAchievements />} />
                      <Route path="/admin/achievements/:id" element={<AdminAchievementDetails />} />
                      <Route path="/admin/goals" element={<AdminGoals />} />
                      <Route path="/admin/goals/:id" element={<AdminGoalDetails />} />
                      <Route path="/admin/events/:id" element={<AdminEventDetails />} />
                      <Route path="/admin/events" element={<AdminEvents />} />
                      <Route path="/admin/resources" element={<AdminResources />} />
                      <Route path="/admin/sessions/:id" element={<AdminSessionDetails />} />
                      <Route path="/admin/sessions" element={<AdminSessions />} />
                      <Route path="/admin/programs/:id" element={<AdminProgramDetails />} />
                      <Route path="/admin/programs" element={<AdminPrograms />} />
                      <Route path="/admin/mentees" element={<AdminMentees />} />
                      <Route path="/admin/users" element={<UsersAndRoles />} />
                      <Route path="/admin/users-roles" element={<UsersAndRoles />} />
                      <Route path="/admin/system-settings" element={<SystemSettings />} />
                      <Route path="/system-settings" element={<SystemSettings />} />
                      
                      {/* Catch all */}
                      <Route path="*" element={<NotFound />} />
                    </Routes>
                  </PlatformBoundary></StartupGate></PlatformProvider></BrowserRouter>
                </MessagingProvider>
              </ServicesProvider>
            </UsersProvider>
          </RoleProvider>
        </AuthProvider>
      </TooltipProvider>
    </HelmetProvider>
  </QueryClientProvider>
);

export default App;
